function [MCSIDX,MCSInfo] = hMCSSelect(carrier,pdsch,pdschExt,W,H,varargin)
% hMCSSelect PDSCH Modulation and coding scheme selection
%   [MCSIDX,MCSINFO] = hMCSSelect(CARRIER,PDSCH,PDSCHEXT,W,H) returns the
%   modulation and coding scheme (MCS) index MCSIDX as defined in TS 38.214
%   Section 5.1.3.1, for the specified carrier configuration CARRIER,
%   physical downlink shared channel (PDSCH) configuration PDSCH,
%   additional PDSCH configuration PDSCHEXT, MIMO precoding matrix W, and
%   estimated channel information H. The function also returns additional
%   information about the reported MCS and expected block error rate (BLER).
%
%   CARRIER is a carrier configuration object, as described in <a href="matlab:help('nrCarrierConfig')">nrCarrierConfig</a>. 
% 
%   PDSCH is a PDSCH configuration object, as described in <a href="matlab:help('nrPDSCHConfig')">nrPDSCHConfig</a>.
%
%   PDSCHEXT is an extended PDSCH configuration structure with these fields:
%   PRGBundleSize   - Number of consecutive RBs with the same MIMO precoder,
%                     as defined in TS 38.214 Section 5.1.2.3. It can be
%                     [], 2, or 4. Use [] to indicate wideband. This field
%                     is optional and its default value is [].
%   XOverhead       - Overhead for transport block size calculation. This
%                     field is optional and its default value is 0.
%   MCSTable        - MCS Table name specified as one of {'Table1','Table2'
%                     ,'Table3','Table4'}, as defined in TS 38.214 Section
%                     5.1.3.1. This field is optional and its default value
%                     is 'Table1'.
%   
%   W is the MIMO precoding matrix of size NumLayers-by-P-by-NPRG.
%   NumLayers is the number of layers, P is the number of reference signal
%   ports, and NPRG the number of precoding resource block group (PRGs) in
%   the BWP.
%
%   H is the channel estimation matrix of size K-by-L-by-NRxAnts-by-P,
%   where K is the number of subcarriers in the carrier resource grid, L is
%   the number of orthogonal frequency division multiplexing (OFDM) symbols
%   spanning one slot, and NRxAnts is the number of receive antennas.  
%
%   MCSIDX is a 1-by-NCW vector containing the lowest MCS indices for each
%   codeword that ensure a transport BLER below 0.1.
%   
%   MCSInfo is a structure with these fields:
%   TableRow        - 1-by-4 vector containing the MCS index, modulation 
%                     order, target code rate, and efficiency for the
%                     configured MCS table and the selected MCS.
%   TransportBLER   - 1-by-NCW vector containing the estimated transport 
%                     BLER for each codeword and the selected MCS index.
%
%   [MCSIDX,MCSINFO] = hMCSSelect(...,NVAR) specifies the estimated noise
%   variance at the receiver NVAR as a nonnegative scalar. By default, the
%   value of NVAR is 1e-10.
%
%   [MCSIDX,MCSINFO] = hMCSSelect(...,NVAR,BLERTARGET) specifies the
%   maximum BLER for the selected MCS index. The function selects the
%   lowest MCS index that ensures a BLER below the BLERTARGET value. The
%   default value is 0.1.

%   Copyright 2022-2024 The MathWorks, Inc.

    narginchk(5,7);
    [pdsch,pdschExt,nVar,BLERTarget,NStartBWP,NSizeBWP] = validateInputs(carrier,pdsch,pdschExt,W,H,varargin{:});

    % Trim H based on BWP bandwidth and freq. position
    bottomsc = 12*(NStartBWP - carrier.NStartGrid);
    topsc = bottomsc + 12*NSizeBWP;
    H = H(1+bottomsc:topsc,:,:,:);

    % Permute to facilitate SINR calculation
    W = permute(W,[2 1 3]); % P-by-NumLayers-by-NPRG

    if size(W,3) > 1 % Subband precoding
        % To calculate the SINR per RE for that precoding matrix, map the input
        % precoder W to the appropriate REs
        K = size(H,1); % Number of subcarriers
        L = size(H,2); % Number of OFDM symbols    
        W = mapMIMOPrecoderToREs(NStartBWP,NSizeBWP,pdschExt.PRGBundleSize,W,K,L);
    end

    % Calculate SINR after MIMO precoding
    Hre = permute(H,[3 4 1 2]);
    SINRsperRE = hPrecodedSINR(Hre(:,:,:),nVar,W(:,:,:));
    
    % Find wideband MCS, effective SINR and estimated BLER per subband
    [MCSIDX,MCSTableRow,BLER] = mcsSelect(carrier,pdsch,pdschExt.XOverhead,SINRsperRE,pdschExt.MCSTable,BLERTarget);

    % Create output info
    MCSInfo = struct();
    MCSInfo.TableRow = MCSTableRow;
    MCSInfo.TransportBLER = BLER;

end

function [mcsIndex,mcsTableRow,transportBLER] = mcsSelect(carrier,pdsch,xOverhead,SINRs,MCSTableName,blerThreshold)

    % Initialize L2SM for MCS calculation
    l2sm = nr5g.internal.L2SM.initialize(carrier);

    % Initialize outputs
    ncw = pdsch.NumCodewords;
    mcsIndex = NaN(1,ncw);
    mcsTableRow = NaN(1,4);
    transportBLER = NaN(1,ncw);    

    % SINR per layer without NaN
    SINRs = 10*log10(SINRs+eps(SINRs));
    nonnan = ~any(isnan(SINRs),2);
    if ~any(nonnan,'all')
        return;
    end
    SINRs = SINRs(nonnan,:);

    % Get modulation orders and target code rates from MCS table
    mcsTable = getMCSTable(MCSTableName);

    % MCS selection
    [~,mcsIndex,mcsInfo] = nr5g.internal.L2SM.cqiSelect(l2sm,carrier,pdsch,xOverhead,SINRs,mcsTable(:,2:3),blerThreshold);
    
    % Get modulation orders and target code rates from MCS table and
    % transport BLER
    mcsTableRow = mcsTable(mcsIndex+1,:);
    transportBLER = mcsInfo.TransportBLER;

end

function WRE = mapMIMOPrecoderToREs(NStartBWP,NSizeBWP,PRGBundleSize,W,K,L)

    % Calculate the number of subbands and size of each subband for the
    % configuration.
    subbandInfo = getSubbandInfo(NStartBWP,NSizeBWP,PRGBundleSize);

    WRE = zeros([size(W,1:2) K L]);
    subbandStart = 0;
    for sb = 1:subbandInfo.NumSubbands
        % Subcarrier indices for this subband
        subbandSize = subbandInfo.SubbandSizes(sb);
        NRE = subbandSize*12;
        k = subbandStart + (1:NRE);

        % Replicate input precoder in this subband for all REs in the
        % subband
        WRE(:,:,k,:) = repmat(W(:,:,sb),1,1,NRE,L);

        % Compute the starting position of next subband
        subbandStart = subbandStart + NRE;
    end

end

function info = getSubbandInfo(nStartBWP,nSizeBWP,NSBPRB)
%   INFO = getSubbandInfo(NSTARTBWP,NSIZEBWP,NSBPRB) returns the subband
%   information.

    % Get the subband information
    if isempty(NSBPRB)
        numSubbands = 1;
        NSBPRB = nSizeBWP;
        subbandSizes = NSBPRB;
    else
        % Calculate the size of first subband
        firstSubbandSize = NSBPRB - mod(nStartBWP,NSBPRB);

        % Calculate the size of last subband
        if mod(nStartBWP + nSizeBWP,NSBPRB) ~= 0
            lastSubbandSize = mod(nStartBWP + nSizeBWP,NSBPRB);
        else
            lastSubbandSize = NSBPRB;
        end

        % Calculate the number of subbands
        numSubbands = (nSizeBWP - (firstSubbandSize + lastSubbandSize))/NSBPRB + 2;

        % Form a vector with each element representing the size of a subband
        subbandSizes = NSBPRB*ones(1,numSubbands);
        subbandSizes(1) = firstSubbandSize;
        subbandSizes(end) = lastSubbandSize;
    end
    % Place the number of subbands and subband sizes in the output
    % structure
    info.NumSubbands = numSubbands;
    info.SubbandSizes = subbandSizes;
end

function [pdsch,pdschExt,nVar,BLERTarget,NStartBWP,NSizeBWP] = validateInputs(carrier,pdsch,pdschExt,W,H,varargin)

    fcnName = 'hMCSSelect';
    
    % Validate the carrier configuration object
    validateattributes(carrier,{'nrCarrierConfig'},{'scalar'},fcnName,'CARRIER');

    % Validate dimensions of channel estimate and precoding matrix
    validateattributes(numel(size(H)),{'double'},{'>=',2,'<=',4},fcnName,'number of dimensions of H');
    K = carrier.NSizeGrid*12;
    L = carrier.SymbolsPerSlot;
    validateattributes(W,{'single','double'},{'size',[NaN size(H,4) NaN]},fcnName,'W');
    validateattributes(H,{class(H)},{'size',[K L NaN size(W,2)]},fcnName,'H');

    % Validate number of layers in W
    numLayers = size(W,1);
    if (numLayers < 1) || (numLayers > 8)
        error(['nr5g:' fcnName ':NumLayers'],'The first dimension of W must be between 1 to 8 elements inclusive.')
    end

    % Validate the PDSCH configuration object
    validateattributes(pdsch,{'nrPDSCHConfig'},{'scalar'},fcnName,'PDSCH');
    
    % Adjust PDSCH with the number of layers provided by W
    pdsch.NumLayers = size(W,1);

    % Validate NStartBWP and NSizeBWP from PDSCH or carrier
    if isempty(pdsch.NStartBWP) || isempty(pdsch.NSizeBWP)
        NStartBWP = carrier.NStartGrid;
        NSizeBWP = carrier.NSizeGrid;
    else
        if (pdsch.NStartBWP < carrier.NStartGrid)
            error(['nr5g:' fcnName ':NStartBWP'],'PDSCH NStartBWP must be >= CARRIER NStartGrid');
        end
        if (pdsch.NStartBWP + pdsch.NSizeBWP) > (carrier.NStartGrid + carrier.NSizeGrid)
            error(['nr5g:' fcnName ':BWPRB'],'The configured BWP is out of the carrier limits. PDSCH (NStartBWP + NSizeBWP) must be <= CARRIER (NStartGrid + NSizeGrid)');
        end
        NStartBWP = pdsch.NStartBWP;
        NSizeBWP = pdsch.NSizeBWP;
    end
    
     % Validate PRGBundleSize
    if isfield(pdschExt,'PRGBundleSize')
        if ~isempty(pdschExt.PRGBundleSize)
            validateattributes(pdschExt.PRGBundleSize,{'double','single'},{'scalar','integer','nonnegative','finite'},fcnName,'PRGBundleSize');
        end
    else
        pdschExt.PRGBundleSize = [];
    end

    % Validate XOverhead
    if isfield(pdschExt,'XOverhead')
        validateattributes(pdschExt.XOverhead,{'numeric'},{'scalar','integer','nonnegative'},fcnName,'XOverhead');
    else
        pdschExt.XOverhead = 0;
    end
    
    % Validate MCS table name
    if isfield('MCSTable',pdschExt)
        validatestring(pdschExt.MCSTable,{'Table1','Table2','Table3','Table4'},fcnName,'MCSTable field');
    else
        pdschExt.MCSTable = 'Table1';
    end

    % Validate noise variance
    nVar = 1e-10;
    BLERTarget = 0.1;
    if nargin > 5
        nVar = varargin{1};
        validateattributes(nVar,{'double','single'},{'scalar','real','nonnegative','finite'},fcnName,'NVAR');
        if nargin > 6
            BLERTarget = varargin{2};
            validateattributes(BLERTarget,{'single','double'},{'scalar','<',1},fcnName,'BLERTarget field');   
        end
    end
    
end

function MCSTable = getMCSTable(tableName)

    persistent tables;
    
    if isempty(tables)
        mcsTableClass = nrPDSCHMCSTables;
        props = ["QAM64Table","QAM256Table","QAM64LowSETable","QAM1024Table"];
        numProps = numel(props);
        for i = 1:numProps
            tmpTable = mcsTableClass.(props(i));
            % l2sm accepts cqitable transmit code rate(tcr) values as tcr/1024
            tmpArray = [tmpTable.MCSIndex tmpTable.Qm (tmpTable.TargetCodeRate)*1024 tmpTable.SpectralEfficiency];
            tables{i} = tmpArray(~isnan(tmpArray(:,3)),:);
        end
    end
    tabNames = {'Table1','Table2','Table3','Table4'};
    MCSTable = tables{strcmpi(tableName,tabNames)};
end
