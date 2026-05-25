%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Version 4

function FUNCTION_Run_5G_Simulation(iFrames, iSimulation_Channel,iRIRestrction, iDoppler_Shift, iPO,iCQIMode,iSubbandSize,iCodeBookMode,iCQITable, iRunID)
    close all force
    
    
    %Based on 3.17 Github release version
    %parpool('local', 20);
    % Can either flex layer + modulation + TCR or flex modulation + TCR
    % Save function added
    % CDL, TDL both supported
    % Constellation Diagram supported
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %TODO
    %检查变量泄露问题
    %检查所有数据是不是都保存到输出文件里面了
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Save_to_File=true; %true, false will save plotted figures too as a reference
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Frames = iFrames;
    Range = -5:1:35;
    RIRestriction = iRIRestrction;
    Perfect_Channel_Estimation= false;
    Doppler_Shift = iDoppler_Shift;
    Simulation_Channel= iSimulation_Channel;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Constellation_Animation=false; %So far can only be used when parfor is off
    
    if strcmpi(iCQIMode, 'wideband')
        CQI_PrefectvPractical = true; 
        Plot_Constellation = false;
    else
        CQI_PrefectvPractical = false; 
        Plot_Constellation = false; %Only can be true if CQI_PrefectvPractical also true
    end
    CQI_Investigation_SNR=[-5,5,15,25];
    Constellation_SNR=[-5, 5, 15, 25]; %Must be four entries

    PO=iPO;  % Peridocity and offset of the CSI report in slots % (4,5,8,10,16,20,32,40,64,80,160,320,640).
    CQIMode = iCQIMode; % 'Wideband','Subband'
    PMIMode = iCQIMode; % 'Wideband','Subband'
    CodebookType = 'Type1SinglePanel'; % 'Type1SinglePanel','Type1MultiPanel','Type2', 'eType2'
        %"Type1MultiPanel", CSI-RS ports must be 8, 16, or 32: -> Only can be used
        %for 8 Tx case.
        %'Type2' max. rank is 2
    SubbandSize = iSubbandSize; % only required for 'subband', subband size in RB (4,8,16,32) 能被BWP size整除, generally 8, 16 for BWP 106 (NSizeGrid)
    CodebookMode = iCodeBookMode; %1, 2 1: sparse, 2: dense, should only be valid to CB1?

    MCSTable=iCQITable;
    CQITable=iCQITable;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    simParameters = struct();       % Clear simParameters variable to contain all key simulation parameters 
    simParameters.NFrames = Frames;      % Number of 10 ms frames
    simParameters.SNRIn = Range; % SNR range (dB)
    
    simParameters.PerfectChannelEstimator = Perfect_Channel_Estimation;
    simParameters.DisplaySimulationInformation = false;
    simParameters.DisplayDiagnostics = false;
    % SCS carrier parameters
    simParameters.Carrier = nrCarrierConfig;         % Carrier resource grid configuration
    simParameters.Carrier.NSizeGrid = 106;            % Bandwidth in number of resource blocks
    simParameters.Carrier.SubcarrierSpacing = 30;    % 15, 30, 60, 120 (kHz)
    simParameters.Carrier.CyclicPrefix = 'Normal';   % 'Normal' or 'Extended' (Extended CP is relevant for 60 kHz SCS only)
    simParameters.Carrier.NCellID = 1;               % Cell identity
    
    simParameters.PDSCH = nrPDSCHConfig;      % This PDSCH definition is the basis for all PDSCH transmissions in the simulation
    
    % Define PDSCH time allocation in a slot
    simParameters.PDSCH.MappingType = "A"; % PDSCH mapping type ('A'(slot-wise),'B'(non slot-wise))
    symAlloc = [2 simParameters.Carrier.SymbolsPerSlot-2];  % Starting symbol and number of symbols of each PDSCH allocation
    simParameters.PDSCH.SymbolAllocation = symAlloc;
    
    % Define PDSCH frequency resource allocation per slot to be full grid 
    simParameters.PDSCH.PRBSet = 0:simParameters.Carrier.NSizeGrid-1;
    
    % Scrambling identifiers
    simParameters.PDSCH.NID = simParameters.Carrier.NCellID;
    simParameters.PDSCH.RNTI = 1;
    
    simParameters.PDSCH.DMRS.DMRSTypeAPosition       = 2; % Mapping type A only. First DM-RS symbol position (2,3)
    simParameters.PDSCH.DMRS.DMRSLength              = 2; % Number of front-loaded DM-RS symbols (1(single symbol),2(double symbol))
    simParameters.PDSCH.DMRS.DMRSAdditionalPosition  = 1; % Additional DM-RS symbol positions (max range 0...3)
    simParameters.PDSCH.DMRS.DMRSConfigurationType   = 1; % DM-RS configuration type (1,2)
    simParameters.PDSCH.DMRS.NumCDMGroupsWithoutData = 1; % CDM groups without data (1,2,3)
    
    simParameters.PDSCHExtension = struct();
    simParameters.PDSCHExtension.PRGBundleSize = 4; % 2, 4, or [] to signify "wideband"
    simParameters.PDSCHExtension.MCSTable      = MCSTable; % 'Table1',...,'Table4'
    simParameters.PDSCHExtension.XOverhead     = [ ]; % 0, 6, 12, 18, or [] for automatic selection.
    
    simParameters.PDSCHExtension.LDPCDecodingAlgorithm = "Normalized min-sum";
    simParameters.PDSCHExtension.MaximumLDPCIterationCount = 6;
    
    simParameters.TransmitAntennaArray.NumPanels        = 1; % Number of transmit panels in horizontal dimension (Ng)
    simParameters.TransmitAntennaArray.PanelDimensions  = [2 1]; % Number of columns and rows in the transmit panel (N1, N2) %[2 1]
    simParameters.TransmitAntennaArray.NumPolarizations = 2; % Number of transmit polarizations %2
    simParameters.ReceiveAntennaArray.NumPanels         = 1; % Number of receive panels in horizontal dimension (Ng)
    simParameters.ReceiveAntennaArray.PanelDimensions   = [2 1];                % Number of columns and rows in the receive panel (N1, N2) % [2 1]
    simParameters.ReceiveAntennaArray.NumPolarizations  = 2; % Number of receive polarizations %2
    
    simParameters.NTxAnts = numAntennaElements(simParameters.TransmitAntennaArray);
    simParameters.NRxAnts = numAntennaElements(simParameters.ReceiveAntennaArray);
    
    simParameters.CSIRS = nrCSIRSConfig;
    simParameters.CSIRS.CSIRSType = 'nzp'; % 'nzp','zp'
    simParameters.CSIRS.RowNumber = 4; % 1...18 % 4
    simParameters.CSIRS.NumRB = simParameters.Carrier.NSizeGrid - simParameters.CSIRS.RBOffset;
    simParameters.CSIRS.CSIRSPeriod = PO;
    simParameters.CSIRS.SymbolLocations = 4;%4
    simParameters.CSIRS.SubcarrierLocations = 0; %0
    simParameters.CSIRS.Density = 'one';
    
    disp(['Number of CSI-RS ports: ' num2str(simParameters.CSIRS.NumCSIRSPorts) '.'])
    
    csirsCDMLengths = getCSIRSCDMLengths(simParameters.CSIRS);
    
    % Check that the number of CSI-RS ports and transmit antenna elements match
    % and the consistency of multiple CSI-RS resources
    validateCSIRSConfig(simParameters.Carrier,simParameters.CSIRS,simParameters.NTxAnts);
    
    simParameters.CSIReportMode = 'RI-PMI-CQI'; % 'RI-PMI-CQI','AI CSI compression','Perfect CSI'
    
    simParameters.CSIReportConfig = struct();
    simParameters.CSIReportConfig.Period = PO;  % Peridocity and offset of the CSI report in slots
    
    if simParameters.CSIReportMode == "RI-PMI-CQI"  
        
        simParameters.CSIReportConfig.CQITable          = CQITable; % 'Table1','Table2','Table3'
        simParameters.CSIReportConfig.CQIMode           = CQIMode; % 'Wideband','Subband'
        simParameters.CSIReportConfig.PMIMode           = PMIMode; % 'Wideband','Subband'
        simParameters.CSIReportConfig.CodebookType      = CodebookType; % 'Type1SinglePanel','Type1MultiPanel','Type2','eType2'
        simParameters.CSIReportConfig.SubbandSize       = SubbandSize; % Subband size in RB (4,8,16,32)
        simParameters.CSIReportConfig.CodebookMode      = CodebookMode; % 1,2
        simParameters.CSIReportConfig.RIRestriction     = RIRestriction;                   % Empty for no rank restriction
        simParameters.CSIReportConfig.NumberOfBeams     = 2; % 2,3,4. Only for Type II codebooks
        simParameters.CSIReportConfig.PhaseAlphabetSize = 8; % 4,8. Only for Type II codebooks  
        simParameters.CSIReportConfig.SubbandAmplitude  = true;                  % true/false. Only for Type II codebooks
        simParameters.CSIReportConfig.ParameterCombination = 1;             % 1...8. Only for Enhanced Type II codebooks
        simParameters.CSIReportConfig.NumberOfPMISubbandsPerCQISubband = 1; % 1,2. Only for Enhanced Type II codebooks
        simParameters.CSIReportConfig.NStartBWP         = [];                                  % Empty to signal the entire carrier
        simParameters.CSIReportConfig.NSizeBWP          = [];                                  % Empty to signal the entire carrier
    
        % Configure the CSI report with the antenna panel dimensions specified
        simParameters.CSIReportConfig.PanelDimensions = getCSIReportPanelDimensions(simParameters.TransmitAntennaArray,simParameters.CSIReportConfig.CodebookType);
        
        % Adjust the rank restriction based on the number of ports supported by
        % the DM-RS configuration, as defined in TS 38.211 Table 7.4.1.1.2-5.
        simParameters.CSIReportConfig.RIRestriction = updateRankRestriction(simParameters.PDSCH.DMRS,simParameters.CSIReportConfig);
    else % AI CSI compression
    
        % Specify the file name of the AI neural network
        simParameters.AINetworkFilename = 'csiTrainedNetwork.mat'; 
    
    end
    
    simParameters.UEProcessingDelay = 7;
    simParameters.BSProcessingDelay = 1;
    
    simParameters.DelayProfile = Simulation_Channel;   % 'CDL-A',...,'CDL-E','TDL-A',...,'TDL-E'
    
    simParameters.DelaySpread = 300e-9;     % s
    simParameters.MaximumDopplerShift = Doppler_Shift;  % Hz
    
    simParameters.Channel = createChannel(simParameters);
    
    % Array to store the maximum throughput for all SNR points
    maxThroughput = zeros(length(simParameters.SNRIn),1); 
    % Array to store the simulation throughput for all SNR points
    simThroughput = zeros(length(simParameters.SNRIn),1);
    log_snr  = cell(numel(simParameters.SNRIn),1);
    log_slot = cell(numel(simParameters.SNRIn),1);
    log_layer = cell(numel(simParameters.SNRIn),1);
    log_mod   = cell(numel(simParameters.SNRIn),1);
    log_tcr  = cell(numel(simParameters.SNRIn),1);
    csiReport_perfect=cell(numel(simParameters.SNRIn),1);
    csiReport_prac=cell(numel(simParameters.SNRIn),1);
    
    % Cell array to store CSI reports per SNR point
    CSIReport = {};
    plotCount=0;
    if Plot_Constellation
        ConstellationResults = struct('snr',[],'rxSymbols',[],'pdsch',[],'throughput',[],'tcr',[]);
        HestResults=struct('h1',[],'h2',[], 'snr', []);4
    end 
    
    parfor snrIdx = 1:numel(simParameters.SNRIn)
    % parfor snrIdx = 1:numel(simParameters.SNRIn)
    % To reduce the total simulation time, you can execute this loop in
    % parallel by using the Parallel Computing Toolbox. Comment out the 'for'
    % statement and uncomment the 'parfor' statement.
        bestThroughput=-3;
        local_bestThroughput = -3;
        local_BestData = struct();
    
        local_h=struct();
    
    
        lsnr   = [];
        lslot  = [];
        llayer = [];
        lmod   = {};
        ltcr   = [];
    
    
        csiReports_perfect=struct('RI', {}, 'CQI', {}, 'PMI', {},'W',{}, 'NSlot',{});
        csiReports_prac=struct('RI', {}, 'CQI', {}, 'PMI', {},'W',{}, 'NSlot',{});
        %csiReports_semi=struct('RI', {}, 'CQI', {}, 'PMI', {},'W',{}, 'NSlot',{});
    
        % Reset the random number generator for repeatability
        %rng(0,"twister");
        currRNG = rng('shuffle'); 
        rng(currRNG.Seed + snrIdx);
        % Display simulation information at this SNR point
        displaySNRPointProgress(simParameters,snrIdx);
    
        % Take full copies of the simulation-level parameter structures so that
        % they are not PCT broadcast variables when using parfor
        simParamLocal = simParameters;
    
        % Extract CSI feedback configuration parameters
        csiFeedbackOpts = getCSIFeedbackOptions(simParamLocal,snrIdx);
    
        % Set up the transmitter, propagation channel, and receiver
        [carrier,encodeDLSCH,pdsch,pdschextra,csirs,wtx] = setupTransmitter(simParamLocal);
        [channel,maxChDelay] = setupChannel(simParamLocal);
        [decodeDLSCH,timingOffset,N0,noiseEst,csiReports,csiAvailableSlots] = setupReceiver(simParamLocal,channel,snrIdx,csiFeedbackOpts);
        
        % Total number of slots in the simulation period
        NSlots = simParamLocal.NFrames * carrier.SlotsPerFrame;
        
        constDiagram = comm.ConstellationDiagram(...
        'Title', 'PDSCH 接收星座图', ...
        'XLimits', [-1.5 1.5], 'YLimits', [-1.5 1.5], ...
        'SamplesPerSymbol', 1);
        
        offsetPractical = 0;
        % Loop over the entire waveform length
        count = 0;
        for nslot = 0:NSlots-1
    
            % Update the carrier slot numbers for new slot
            carrier.NSlot = nslot;
    
            % Use new CSI report to configure the number of layers and
            % modulation of the PDSCH and target code rate of the DL-SCH if
            % there is a new report available.
            [isNewReport,repIdx] = ismember(nslot,csiAvailableSlots);
            if isNewReport
                [pdsch.Modulation,pdschextra.TargetCodeRate,wtx] = hCSIDecode(carrier,pdsch,pdschextra,csiReports(repIdx),csiFeedbackOpts);
                pdsch.NumLayers = size(wtx,1);
                encodeDLSCH.TargetCodeRate = pdschextra.TargetCodeRate;
            end
            lsnr(end+1)   = simParameters.SNRIn(snrIdx);
            lslot(end+1)  = nslot;
            lmod{end+1} = char(pdsch.Modulation);
            llayer(end+1) = double(pdsch.NumLayers);
            ltcr(end+1)   = pdschextra.TargetCodeRate;
            
    
            % Create an OFDM resource grid for a slot
            dlGrid = nrResourceGrid(carrier,csirs.NumCSIRSPorts);
    
            % CSI-RS mapping to the slot resource grid
            [csirsInd,csirsInfo] = nrCSIRSIndices(carrier,csirs);
            csirsSym = nrCSIRS(carrier,csirs);
            dlGrid(csirsInd) = csirsSym;
            csirsTransmission = ~isempty(csirsInd);
    
            % PDSCH reserved REs for CSI-RS
            pdsch.ReservedRE = csirsInd-1; % 0-based indices
            
            % PDSCH generation
            % Calculate the transport block sizes for the transmission in the slot
            [pdschIndices,pdschIndicesInfo] = nrPDSCHIndices(carrier,pdsch);
            trBlkSizes = nrTBS(pdsch.Modulation,pdsch.NumLayers,numel(pdsch.PRBSet),pdschIndicesInfo.NREPerPRB,pdschextra.TargetCodeRate,pdschextra.XOverhead);
            
            
            %------------------------------- %Generate Resource Grid Plot
            if (nslot == 0) && snrIdx == floor(numel(simParameters.SNRIn)/2)
                ports = max(simParameters.CSIRS.NumCSIRSPorts); 
                txGrid = nrResourceGrid(carrier, ports);
                
                % 仅针对第一个天线端口创建 2D 显示网格
                % 这样坐标轴的"子载波索引"才和实际物理网格对应
                displayGrid = zeros(size(txGrid, 1), size(txGrid, 2)); 
                
                % --- 填入索引（注意使用线性索引时要限制在单层内，或提取 2D 坐标） ---
                % 这里的逻辑：利用 ind2sub 提取坐标，只画出属于第一层（天线 1）的资源
                [subK, subL, subR] = ind2sub(size(txGrid), pdschIndices);
                firstLayerIdx = (subR == 1);
                displayGrid(subK(firstLayerIdx) + (subL(firstLayerIdx)-1)*size(displayGrid,1)) = 1;
                
                % DMRS 同理
                [dmrsK, dmrsl, dmrsR] = ind2sub(size(txGrid), nrPDSCHDMRSIndices(carrier,pdsch));
                dmrsFirstLayer = (dmrsR == 1);
                displayGrid(dmrsK(dmrsFirstLayer) + (dmrsl(dmrsFirstLayer)-1)*size(displayGrid,1)) = 2;
                
                % CSI-RS 同理
                
                [csiK, csiL, csiR] = ind2sub(size(txGrid), csirsInd);
                csiFirstLayer = (csiR == 1);
                displayGrid(csiK(csiFirstLayer) + (csiL(csiFirstLayer)-1)*size(displayGrid,1)) = 3;
               
                
                % --- 绘图 --- 
                figure('Name', '5G Resource Grid');
                imagesc(displayGrid);
                axis xy; 
                % 这里的 colormap 长度应与你的分类匹配
                % [背景, PDSCH, DMRS, CSIRS]
                colormap([0.5 0.5 0.5; 0.2 0.4 0.8; 0.9 0.7 0.2; 0.9 0.4 0.2]);  
                xlabel('OFDM Symbols');
                ylabel('Subcarriers');
                title('Resource Grid');
                
                ylim([10 50]);
                % 调整 colorbar 使其居中对齐标签
                cb = colorbar('Ticks', [0.375, 1.125, 1.875, 2.625], ...
                              'TickLabels', {'Empty', 'PDSCH', 'DM-RS', 'CSI-RS'});
            end 
            %----------------------- End Resource Grid Plot
    
    
            % Transport block generation
            for cwIdx = 1:pdsch.NumCodewords
                % New data for current codeword then create a new DL-SCH transport block
                trBlk = randi([0 1],trBlkSizes(cwIdx),1);
                setTransportBlock(encodeDLSCH,trBlk,cwIdx-1);
                resetSoftBuffer(decodeDLSCH,cwIdx-1);
            end
    
            % Encode the DL-SCH transport blocks
            RV = zeros(1,pdsch.NumCodewords);
            codedTrBlocks = encodeDLSCH(pdsch.Modulation,pdsch.NumLayers, ...
                pdschIndicesInfo.G,RV);
    
            % PDSCH modulation and precoding
            pdschSymbols = nrPDSCH(carrier,pdsch,codedTrBlocks);
            [pdschAntSymbols,pdschAntIndices] = nrPDSCHPrecode(carrier,pdschSymbols,pdschIndices,wtx);
            dlGrid(pdschAntIndices) = pdschAntSymbols;        
    
            % PDSCH DM-RS precoding and mapping
            dmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
            dmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);
            [dmrsAntSymbols,dmrsAntIndices] = nrPDSCHPrecode(carrier,dmrsSymbols,dmrsIndices,wtx);
            dlGrid(dmrsAntIndices) = dmrsAntSymbols;
    
            % Warn if CSI-RS and PDSCH DM-RS resources overlap
            if any(ismember(dmrsIndices,csirsInd))
                warning("CSI-RS and PDSCH DM-RS resources overlap in the resource grid. This can result in decoding failures.")
            end
    
            % OFDM modulation
            txWaveform = nrOFDMModulate(carrier,dlGrid);
    
            % Pass data through channel model. Append zeros at the end of the
            % transmitted waveform to flush channel content. These zeros take
            % into account any delay introduced in the channel.
            txWaveform = [txWaveform; zeros(maxChDelay,size(txWaveform,2))]; %#ok<AGROW>
            [rxWaveform,ofdmResponse,tOffset] = channel(txWaveform,carrier);
            
            % Add AWGN to the received time-domain waveform
            noise = N0*randn(size(rxWaveform),"like",1i);
            rxWaveform = rxWaveform + noise;
    
            %---------------------------------- %Begin CQI Perfect vs Practical
            if CQI_PrefectvPractical 
                timingOffset_perfect = tOffset;
    
                [t_prac,mag_prac] = nrTimingEstimate(carrier,rxWaveform,dmrsIndices,dmrsSymbols); 
                timingOffset_prac = hSkipWeakTimingOffset(timingOffset,t_prac,mag_prac);
    
                
                %[pathGains, sampleTimes] = getPathGains(channel); % 确保能获取到这些变量
                %[rxWaveform, pathGains, sampleTimes] = channel(txWaveform, 0);
                %timingOffset_semi = tOffset;
                %dt = t_prac - tOffset; 
                %K = size(ofdmResponse, 1);
                %k = (0:K-1)' - (K/2); % 子载波索引中心化
                %waveInfo = nrOFDMInfo(carrier);
                %Nfft = waveInfo.Nfft;
                %phaseRotation = exp(-1i * 2 * pi * dt * k / Nfft);
                %Hest_semi = ofdmResponse .* reshape(phaseRotation, K, 1, 1, 1);
    
                rxWaveform_perfect = rxWaveform(1+timingOffset_perfect:end,:);
                rxWaveform_prac = rxWaveform(1+timingOffset_prac:end,:);
    
                rxGrid_perfect = nrOFDMDemodulate(carrier,rxWaveform_perfect);
                rxGrid_prac = nrOFDMDemodulate(carrier,rxWaveform_prac);
                %rxGrid_semi    = nrOFDMDemodulate(carrier, rxWaveform_semi);
    
                [K_perfect,L_perfect,R_perfect] = size(rxGrid_perfect);
                if (L_perfect < carrier.SymbolsPerSlot)
                    rxGrid_perfect = cat(2,rxGrid_perfect,zeros(K_perfect,carrier.SymbolsPerSlot-L_perfect,R_perfect));
                end
                [K_prac,L_prac,R_prac] = size(rxGrid_prac);
                if (L_prac < carrier.SymbolsPerSlot)
                    rxGrid_prac = cat(2,rxGrid_prac,zeros(K_prac,carrier.SymbolsPerSlot-L_prac,R_prac));
                end
    
                Hest_perfect = ofdmResponse;
                [pdschRx_perfect,pdschHest_perfect,~,pdschHestIndices_perfect] = nrExtractResources(pdschIndices,rxGrid_perfect,Hest_perfect);
                pdschHest_perfect = nrPDSCHPrecode(carrier,pdschHest_perfect,pdschHestIndices_perfect,permute(wtx,[2 1 3]));
    
                [Hest_prac,noiseEst_prac] = nrChannelEstimate(carrier,rxGrid_prac,dmrsIndices,dmrsSymbols,PRGBundleSize = pdschextra.PRGBundleSize,CDMLengths = pdsch.DMRS.CDMLengths);
                noiseEst_prac = mean(noiseEst_prac,'all');
                [pdschRx_prac,pdschHest_prac] = nrExtractResources(pdschIndices,rxGrid_prac,Hest_prac);
    
                noiseGrid_ideal = nrOFDMDemodulate(carrier, noise(1+timingOffset_perfect:end, :));
                nVar_ideal = var(noiseGrid_ideal(:));
                
                if csirsTransmission    
                    nzpind_prac = (csirsSym ~= 0);
                    [Hest_prac,noiseEst_prac] = nrChannelEstimate(carrier,rxGrid_prac, ...
                        csirsInd(nzpind_prac),csirsSym(nzpind_prac),'CDMLengths',csirsCDMLengths);
                    rxCSIReport_perfect = hCSIEncode(carrier,csirs,Hest_perfect,noiseEst,csiFeedbackOpts);
                    csiReports_perfect(end+1) = rxCSIReport_perfect; %#ok<SAGROW>
    
                    rxCSIReport_prac = hCSIEncode(carrier,csirs,Hest_prac,noiseEst_prac,csiFeedbackOpts);
                    csiReports_prac(end+1) = rxCSIReport_prac; %#ok<SAGROW>
                   
                    %rxCSIReport_semi = hCSIEncode(carrier, csirs, Hest_semi, nVar_ideal, csiFeedbackOpts);
                    %csiReports_semi(end+1)    = rxCSIReport_semi;
                    if count == 1 && ismember(simParameters.SNRIn(snrIdx), CQI_Investigation_SNR)
                        % Plot the estimated channel
                        local_h.h1=abs(Hest_prac(100:300,:,1,1));
                        local_h.h2=abs(Hest_perfect(100:300,:,1,1));
                    
                    end 
                    count=count+1;
                end
    
    
              
    
            end
            %---------------------------------- %End CQI Perfect vs Practical
    
            if simParamLocal.PerfectChannelEstimator
                % For perfect synchronization, use the timing offset obtained
                % from the channel
                timingOffset = tOffset;
            else
                % Practical synchronization. Correlate the received waveform
                % with the PDSCH DM-RS to obtain the timing offset and
                % correlation magnitude. The receiver updates the timing offset
                % only when the correlation magnitude is high.
                [t,mag] = nrTimingEstimate(carrier,rxWaveform,dmrsIndices,dmrsSymbols); 
                timingOffset = hSkipWeakTimingOffset(timingOffset,t,mag);
                % Display a warning if the estimated timing offset exceeds the
                % maximum channel delay
                if timingOffset > maxChDelay
                    %warning(['Estimated timing offset (%d) is greater than the maximum channel delay (%d).' ...
                     %   ' This will result in a decoding failure. This may be caused by low SNR,' ...
                      %  ' or not enough DM-RS symbols to synchronize successfully.'],timingOffset,maxChDelay);
                end
            end
            rxWaveform = rxWaveform(1+timingOffset:end,:);
    
            % Perform OFDM demodulation on the received data to recreate the
            % resource grid, including padding in the event that practical
            % synchronization results in an incomplete slot being demodulated
            rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
    
            
            [K,L,R] = size(rxGrid);
            if (L < carrier.SymbolsPerSlot)
                rxGrid = cat(2,rxGrid,zeros(K,carrier.SymbolsPerSlot-L,R));
            end
            %pdschRaw = rxGrid(pdschIndices);
            %constDiagram(pdschRaw(:,1))
            if simParamLocal.PerfectChannelEstimator
                % For perfect channel estimate, use the OFDM channel response
                % obtained from the channel
                Hest = ofdmResponse;
    
                % Get PDSCH resource elements from the received grid and 
                % channel estimate
                [pdschRx,pdschHest,~,pdschHestIndices] = nrExtractResources(pdschIndices,rxGrid,Hest);
    
                % Apply precoding to channel estimate
                pdschHest = nrPDSCHPrecode(carrier,pdschHest,pdschHestIndices,permute(wtx,[2 1 3]));
            else
                % Practical channel estimation between the received grid and
                % each transmission layer, using the PDSCH DM-RS for each
                % layer. This channel estimate includes the effect of
                % transmitter precoding
                [Hest,noiseEst] = nrChannelEstimate(carrier,rxGrid,dmrsIndices,dmrsSymbols,PRGBundleSize = pdschextra.PRGBundleSize,CDMLengths = pdsch.DMRS.CDMLengths);
    
                % Average noise estimate across PRGs and layers
                noiseEst = mean(noiseEst,'all');
                
                % Get PDSCH resource elements from the received grid and
                % channel estimate
                [pdschRx,pdschHest] = nrExtractResources(pdschIndices,rxGrid,Hest);
            end
    
            % Equalization
            [pdschEq,eqCSIScaling] = nrEqualizeMMSE(pdschRx,pdschHest,noiseEst);
            
            %constDiagram(pdschEq(:,2));
            %pdschEq = pdschEq .*exp(1i * 2 * pi * -200 *
            %(0:length(pdschEq)-1)' / channel.SampleRate); %人为加入CFO噪音
    
            % Decode PDSCH physical channel
            [dlschLLRs,rxSymbols] = nrPDSCHDecode(carrier,pdsch,pdschEq,noiseEst);
            
            %---------------------------------- Constellation Diagram
            if Constellation_Animation
                constDiagram(rxSymbols{1});
            end
            %----------------------------------
    
            % Display EVM per layer, per slot and per RB
            if (simParamLocal.DisplayDiagnostics)
                plotLayerEVM(NSlots,nslot,pdsch,size(dlGrid),pdschIndices,pdschSymbols,pdschEq);
            end
            
            % Scale LLRs
            eqCSIScaling = nrLayerDemap(eqCSIScaling); % CSI scaling layer demapping
            for cwIdx = 1:pdsch.NumCodewords
                Qm = length(dlschLLRs{cwIdx})/length(rxSymbols{cwIdx});        % bits per symbol
                eqCSIScaling{cwIdx} = repmat(eqCSIScaling{cwIdx}.',Qm,1);      % expand by each bit per symbol
                dlschLLRs{cwIdx} = dlschLLRs{cwIdx} .* eqCSIScaling{cwIdx}(:); % scale LLRs
            end
            
            % Decode the DL-SCH transport channel
            decodeDLSCH.TransportBlockLength = trBlkSizes;
            decodeDLSCH.TargetCodeRate = pdschextra.TargetCodeRate;
            [decbits,blkerr] = decodeDLSCH(dlschLLRs,pdsch.Modulation,pdsch.NumLayers,RV);
    
            % Store values to calculate throughput
            simThroughput(snrIdx) = simThroughput(snrIdx) + sum(~blkerr .* trBlkSizes);
            maxThroughput(snrIdx) = maxThroughput(snrIdx) + sum(trBlkSizes);
    
            log_snr{snrIdx}   = lsnr;
            log_slot{snrIdx}  = lslot;
            log_layer{snrIdx} = llayer;
            log_mod{snrIdx}   = lmod;
            log_tcr{snrIdx}   = ltcr;
            %fprintf("  trBlkSizes: [%d %d]\n", trBlkSizes(1), trBlkSizes(2));
            %fprintf("  blkerr:     [%d %d]\n", blkerr(1), blkerr(2));
            %fprintf("  Mod:        {'%s','%s'}\n", pdsch.Modulation{1}, pdsch.Modulation{2});
            %fprintf("  TCR:        [%.3f %.3f]\n", pdschextra.TargetCodeRate(1), pdschextra.TargetCodeRate(2));
            % CSI measurements and encoding 
            if csirsTransmission    
                if ~simParamLocal.PerfectChannelEstimator
                    % Consider only the NZP-CSI-RS symbols and indices for CSI-RS based
                    % channel estimation
                    nzpind = (csirsSym ~= 0);
                    
                    % Calculate practical channel estimate based on CSI-RS. Use
                    % a time-averaging window that covers all of the
                    % transmitted CSI-RS symbols.
                    [Hest,noiseEst] = nrChannelEstimate(carrier,rxGrid, ...
                        csirsInd(nzpind),csirsSym(nzpind),'CDMLengths',csirsCDMLengths);
                end
    
                % Generate CSI report. Store the report for use at the
                % transmitter. The CSI feedback is subject to a delay that
                % depends on the CSI report periodicity and the UE processing
                % delay. The slot in which the CSI is available to use at the
                % transmitter depends on the BS processing delay as well.
                rxCSIReport = hCSIEncode(carrier,csirs,Hest,noiseEst,csiFeedbackOpts);
                csiFeedbackSlot = nextCSISlot(csiFeedbackOpts.CSIReportPeriod,1+nslot+simParamLocal.UEProcessingDelay);
                csiAvailableSlots(end+1) = 1+csiFeedbackSlot+simParamLocal.BSProcessingDelay; %#ok<SAGROW>
                csiReports(end+1) = rxCSIReport; %#ok<SAGROW>
            end
    
            % Print slot-wise information
            if simParamLocal.DisplaySimulationInformation
                printSlotInfo(NSlots,carrier,pdsch,pdschextra,blkerr,trBlkSizes./pdschIndicesInfo.G,csirsTransmission,csiReports,repIdx)
            end
            if ismember(simParameters.SNRIn(snrIdx), Constellation_SNR)
                if simThroughput(snrIdx)>local_bestThroughput
                    local_bestThroughput=simThroughput(snrIdx);
                    local_BestData.pdsch=pdsch;
                    local_BestData.tcr=pdschextra.TargetCodeRate;
                    local_BestData.pdsch.NumLayers=pdsch.NumLayers;
                else local_bestThroughput<0;
                    local_bestThroughput = 0;
                    local_BestData.pdsch=pdsch;
                    local_BestData.tcr=pdschextra.TargetCodeRate;
                    local_BestData.pdsch.NumLayers=pdsch.NumLayers;
                end 
            end 
    
    
        end
    
        % Store CSI report for each SNR point
        CSIReport{snrIdx} = csiReports; %#ok<SAGROW>
        CSIReport_perfect{snrIdx} = csiReports_perfect;
        CSIReport_prac{snrIdx} = csiReports_prac;
        %CSIReport_semi{snrIdx} = csiReports_semi;
        
    
        % Display the results dynamically in the command window
        if simParamLocal.DisplaySimulationInformation
            fprintf('\n');
        end
        fprintf('\nThroughput(Mbps) for %d frame(s) = %.4f\n',simParamLocal.NFrames,1e-6*simThroughput(snrIdx)/(simParamLocal.NFrames*10e-3));
        
        %constellation
        
        if Plot_Constellation
            if ismember(simParameters.SNRIn(snrIdx), Constellation_SNR)
                ConstellationResults(snrIdx).snr = simParameters.SNRIn(snrIdx);
                ConstellationResults(snrIdx).rxSymbols = rxSymbols{1}; 
                ConstellationResults(snrIdx).pdsch = local_BestData.pdsch;  
                ConstellationResults(snrIdx).throughput = 1e-6 * local_bestThroughput / (simParameters.NFrames * 10e-3);
                ConstellationResults(snrIdx).tcr = local_BestData.tcr;
            end
        
            if ismember(simParameters.SNRIn(snrIdx), CQI_Investigation_SNR) && CQI_PrefectvPractical
                HestResults(snrIdx).h1=local_h.h1;
                HestResults(snrIdx).h2=local_h.h2;
                HestResults(snrIdx).snr=simParameters.SNRIn(snrIdx);
            end
        end 
    
    end
    
    if Plot_Constellation
        ConstellationResults = ConstellationResults(~cellfun(@isempty, {ConstellationResults.snr}));
        HestResults=HestResults(~cellfun(@isempty, {HestResults.snr}));
    end 
    
    %-------------------------------------------------- Plot Generation Region
    log_tcr_f=vertcat(log_tcr{:});
    log_layer_f=vertcat(log_layer{:});
    log_slot_f=vertcat(log_slot{:});
    log_mod_f=vertcat(log_mod{:});
    
    log_tcr_mean = mean(log_tcr_f, 2);
    log_layer_mean = mean(log_layer_f, 2);
    
    if Perfect_Channel_Estimation
        estStr = 'perfect';
    else
        estStr = 'practical';
    end
    
    if Save_to_File
        timestamp = datestr(datetime('now'), 'yyyy-mm-dd_HHMM');
        filename = sprintf( ...
        '%s_%s_L%s_%dHz_%s_%d', ...
        timestamp, ...
        simParameters.DelayProfile, ...
        rankrestrictionfromRI(RIRestriction), ...
        simParameters.MaximumDopplerShift, ...
        estStr,iRunID);
        resultsFolder = './results_updated/';
        fullResultsPath = fullfile(resultsFolder, filename);
    
        if ~exist(fullResultsPath, 'dir')
            mkdir(fullResultsPath);
        end
    end
       
       
    
    snrVals = simParameters.SNRIn;
    nSNR = numel(snrVals);
    
    mods = {'QPSK','16QAM','64QAM','256QAM'};
    nMod = numel(mods);
    
    modFrac = zeros(nSNR, nMod);  % 每行一个 SNR
    
    for i = 1:nSNR
        m = log_mod{i};      % cell array of char
        N = numel(m);
        for k = 1:nMod
            modFrac(i,k) = sum(strcmp(m, mods{k})) / N;
        end
    end
    
    tcrFrac = zeros(nSNR,3); % low / mid / high
    
    for i = 1:nSNR
        tcr = log_tcr{i};
        N = numel(tcr);
    
        tcrFrac(i,1) = sum(tcr < 0.4) / N;
        tcrFrac(i,2) = sum(tcr >= 0.4 & tcr < 0.6) / N;
        tcrFrac(i,3) = sum(tcr >= 0.6) / N;
    end
    
    %Practical vs theoretical CSI feedbacks
    
    if CQI_PrefectvPractical
        %&& ismember(simParameters.SNRIn(snrIdx), CQI_Investigation_SNR)
        [Lia, Locb] = ismember(CQI_Investigation_SNR, Range);
        validIdx = Locb(Lia);
        %validIdx = cellfun(@(x) ~isempty(x) && all(size(x) > 0), CSIReport_perfect);
        perf_valid = CSIReport_perfect(validIdx);
        prac_valid = CSIReport_prac(validIdx);
        %semi_valid=CSIReport_semi(validIdx);
        numValidSNRs = length(perf_valid);
        maxM=50;
        for s = 1:numValidSNRs
            currentM = length(perf_valid{s});
            limitM = min(currentM, maxM);
            perf_data = perf_valid{s}(1:limitM); % 这是一个 1xM 的 struct array
            prac_data = prac_valid{s}(1:limitM);
            %semi_data= semi_valid{s}(1:limitM);
            M = length(perf_data);
            x_axis = 1:M; % 横轴：通常是 Subbands 或 Slots
            
            % --- 预分配内存 (提高速度且防止维度报错) ---
            p_RI = zeros(1, M); p_CQI = zeros(1, M); p_PMI = zeros(1, M);
            r_RI = zeros(1, M); r_CQI = zeros(1, M); r_PMI = zeros(1, M);
            
            % --- 循环提取数据 ---
            for m = 1:M
                % Perfect 数据提取
                p_RI(m)  = perf_data(m).RI;
                p_CQI(m) = perf_data(m).CQI(1); % 强制取第一个，防止万一有双码字
                % 动态判断 PMI 字段
                p_i11(m) = perf_data(m).PMI.i1(1);
                p_i12(m) = perf_data(m).PMI.i1(2);
                p_i13(m) = perf_data(m).PMI.i1(3);
                p_i2(m)  = perf_data(m).PMI.i2;
        
                % Practical
                r_i11(m) = prac_data(m).PMI.i1(1);
                r_i12(m) = prac_data(m).PMI.i1(2);
                r_i13(m) = prac_data(m).PMI.i1(3);
                r_i2(m)  = prac_data(m).PMI.i2;
    
                            % Practical 数据提取
                r_RI(m)  = prac_data(m).RI;
                r_CQI(m) = prac_data(m).CQI(1);
    
                %semi
                %s_i11(m) = semi_data(m).PMI.i1(1);
                %s_i12(m) = semi_data(m).PMI.i1(2);
                %s_i13(m) = semi_data(m).PMI.i1(3);
                %s_i2(m)  = semi_data(m).PMI.i2;
    
                %s_RI(m)  = semi_data(m).RI;
                %s_CQI(m) = semi_data(m).CQI(1);
                
    
            end
            
            % --- 绘图 ---
            figure('Name', "Practival vs Real", ...
                   'NumberTitle', 'off', ...
                   'Color', 'w', ...
                   'Position', [100, 100, 1000, 900], ... % 仅在 WindowStyle 为 normal 时生效
                   'WindowStyle', 'docked');
            
            thisSNR = CQI_Investigation_SNR(Lia);
            currentSNR =  thisSNR(s);
    
            % 图1: RI
            subplot(3,1,1);
            plot(x_axis, p_RI, 'b-o', 'LineWidth', 1.5); hold on;
            plot(x_axis, r_RI, 'r--x', 'LineWidth', 1);
            ylabel('RI'); title(['SNR Index ', num2str(s), ' - Performance Comparison']);
            legend('Perfect', 'Practical'); grid on;
            
            % 图2: CQI
            subplot(3,1,2);
            plot(x_axis, p_CQI, 'b-s', 'LineWidth', 1.5); hold on;
            plot(x_axis, r_CQI, 'r--d', 'LineWidth', 1);
            %plot(x_axis, s_CQI, 'r--d', 'LineWidth', 1);
            ylabel('CQI'); grid on;
            
            % 图3: PMI (用阶梯图更符合索引跳变的物理特性)
            subplot(3,1,3);
            stairs(x_axis, p_i11, 'b', 'LineWidth', 1.5); hold on;
            stairs(x_axis, r_i11, 'r--', 'LineWidth', 1);
            ylabel('PMI (i11)'); xlabel('Slots');
            grid on;
        
            sgtitle(sprintf('CSI Report Comparison (SNR: %d)', currentSNR), ...
                    'FontSize', 14, 'FontWeight', 'bold');
        
            if Save_to_File
                saveas(gcf, fullfile(fullResultsPath, sprintf('PractivalvsActualCSI_SNR%d.png', currentSNR)));
            end  
        end
    end
    
    %Constellation
    
    if Plot_Constellation
        figure('Name','Constellation', 'NumberTitle','off','Color', 'w', 'Position', [100, 100, 1000, 900],'WindowStyle', 'docked', 'NumberTitle','off');
        for i = 1:length(ConstellationResults)
            ax = subplot(2,length(ConstellationResults) , i);  
            res = ConstellationResults(i);
            modType = res.pdsch.Modulation{1}; % May need to add {1}
            refSymbols = getConstellationPoints(modType, res.pdsch.NumCodewords);
            plot(res.rxSymbols, '.', 'Color', [0.5 0.5 0.5], 'MarkerSize', 1); % 实测点用灰色，方便看红十字
            hold on
            plot(refSymbols, 'r+', 'MarkerSize', 8, 'LineWidth', 1.2);
            hold off
            line1 = sprintf('SNR: %.1f dB | Mod: %s', res.snr, modType);
            line2 = sprintf('TCR: %.3f | Layers: %d | Thr: %.1f Mbps', ...
                            res.tcr, res.pdsch.NumLayers, res.throughput);
            
            titleStr = {line1, line2};
            title(titleStr,'FontSize', 9);
            grid on
            axis square
            axis([-1.5 1.5 -1.5 1.5]); % 固定坐标系，防止 256QAM 切换到 QPSK 时坐标乱跳
            xlabel('In-Phase')
            ylabel('Quadrature')
        end
        if Save_to_File
            saveas(gcf, fullfile(fullResultsPath,  'Constellation.png'));
        end    
    end
    
    if Plot_Constellation
        figure('Name', 'H for estimated and actual channel', 'NumberTitle','off');
        for i = 1:length(HestResults)
            data=HestResults(i);
            data1=data.h1;
            data2=data.h2;
            maxVal = max([max(data1(:)), max(data2(:))]);
            minVal = min([min(data1(:)), min(data2(:))]);
            
            subplot(2,length(HestResults),i)
            h1=imagesc(data1);
            colorbar;
            clim([minVal, maxVal]);
            line1 = "Estimated Channel";
            line2 = sprintf('SNR: %.1f dB' , data.snr);
            
            titleStr = {line1, line2};
            title(titleStr);
            axis xy;
            xlabel('OFDM Symbols');
            ylabel('Subcarriers');
            
            % Plot the actual channel
            subplot(2,length(HestResults),i+length(HestResults))
            h2=imagesc(data2);
            colorbar;
            clim([minVal, maxVal]);
            line1 = "Actual Channel";
            line2 = sprintf('SNR: %.1f dB' , data.snr);
            
            titleStr = {line1, line2};
            title(titleStr);
            axis xy;
            xlabel('OFDM Symbols');
            ylabel('Subcarriers');
        end 
        if Save_to_File
            saveas(gcf, fullfile(fullResultsPath,  'H_est_act.png'));
        end  
    end
    
    figure('Name','Throughput % vs SNR', 'NumberTitle','off','WindowStyle', 'docked');
    plot(simParameters.SNRIn, 100* simThroughput./maxThroughput, '-s', 'LineWidth', 1.5);
    xlabel('SNR (dB)');
    ylabel('Throughput (%)');
    grid on;
    title(sprintf('%s (%dx%d) / NRB=%d / SCS=%dkHz / CSI: %s', ...
                  simParameters.DelayProfile,simParameters.NTxAnts,simParameters.NRxAnts, ...
                  simParameters.Carrier.NSizeGrid,simParameters.Carrier.SubcarrierSpacing,...
                  char(simParameters.CSIReportMode)));
    if Save_to_File
        saveas(gcf, fullfile(fullResultsPath,  'Throughput% vs SNR.png'));
    end
    
    figure('Name','Throughput Mbps vs SNR', 'NumberTitle','off');
    plot(simParameters.SNRIn,1e-6*simThroughput/(simParameters.NFrames*10e-3),'o-.')
    xlabel('SNR (dB)'); ylabel('Throughput (Mbps)'); grid on;
    title(sprintf('%s (%dx%d) / NRB=%d / SCS=%dkHz / CSI: %s', ...
                  simParameters.DelayProfile,simParameters.NTxAnts,simParameters.NRxAnts, ...
                  simParameters.Carrier.NSizeGrid,simParameters.Carrier.SubcarrierSpacing,...
                  char(simParameters.CSIReportMode)));
    if Save_to_File
        saveas(gcf, fullfile(fullResultsPath, 'Mbps vs SNR.png'));
    end
    
    figure('Name','Modulation selection vs SNR', 'NumberTitle','off');
    bar(snrVals, modFrac, 'stacked');
    xlabel('SNR (dB)');
    ylabel('Probability');
    legend(mods, 'Location','northwest');
    title('Modulation distribution per SNR');
    if Save_to_File
        saveas(gcf, fullfile(fullResultsPath, 'Modulation_Selection_vs_SNR.png')); % Save as image
    end
    
    figure('Name','Target code rate distribution vs SNR', 'NumberTitle','off');
    subplot(1,2,1)
    bar(snrVals, tcrFrac, 'stacked');
    xlabel('SNR (dB)');
    ylabel('Probability');
    legend({'Low TCR','Mid TCR','High TCR'}, 'Location','northwest');
    title('Target code rate distribution per SNR');
    
    subplot(1,2,2);  % 当前是第二个子图
    plot(snrVals, log_tcr_mean, '-o', 'LineWidth', 2);
    xlabel('SNR (dB)');
    ylabel('Average TCR');
    title('Average TCR per SNR');
    grid on;
    
    if Save_to_File
        saveas(gcf, fullfile(fullResultsPath,'Target_Code_Rate_vs_SNR.png')); % Save as image
    end 
    
    figure('Name','Layer selection behaviour vs SNR', ...
           'NumberTitle','off');
    hold on;
    
    
    snrVals = simParameters.SNRIn;
    nSNR = numel(snrVals);
    
    meanLayer = zeros(nSNR,1);
    
    baseColor = [0.1 0.3 0.6];   % 单一颜色（深蓝，论文友好）
    
    for i = 1:nSNR
        L = log_layer{i};
    
        % mean layer
        meanLayer(i) = mean(L);
    
        % unique layers at this SNR
        layers = unique(L);
    
        for k = 1:numel(layers)
            lv = layers(k);
            p  = mean(L == lv);   % probability
    
            % bubble size (area scaling)
            bubbleSize = 900 * p + 20;  % 可微调 900 / 20
    
            scatter(snrVals(i), lv, bubbleSize, ...
                'MarkerFaceColor', baseColor, ...
                'MarkerEdgeColor', 'none', ...
                'MarkerFaceAlpha', 0.5);
        end
    end
    
    % mean curve
    plot(snrVals, meanLayer, '-k', ...
        'LineWidth', 2);
    
    xlabel('SNR (dB)');
    ylabel('Number of layers');
    title('Layer selection behaviour (bubble size = probability)');
    grid on;
    % 强制 y 轴整数
    yticks(1:max(cellfun(@max,log_layer)));
    
    legend({'Layer selection probability','Mean number of layers'}, ...
           'Location','northwest');
    
    if Save_to_File
        saveas(gcf, fullfile(fullResultsPath, 'Layer_Selection_vs_SNR.png'));
    end
    
    if simParameters.CSIReportMode == "RI-PMI-CQI"
        perc = 90;
        if strcmpi(CQIMode, "Wideband")
            cqiStats = plotCQI(simParameters,CSIReport,perc) ;
        else 
            cqiStats = plotSubbandCQI(simParameters,CSIReport,perc) ;
        end
        if Save_to_File
                saveas(gcf, fullfile(fullResultsPath, 'CQI.png'));
                simResults.CSI.CQI_Stats_Table = cqiStats;
        end
        
        riStats = plotRank(simParameters,CSIReport,perc) ;
        if Save_to_File
            saveas(gcf, fullfile(fullResultsPath, 'RI.png'));
            simResults.CSI.RI_Stats_Table = riStats;
        end
        
        if CQI_PrefectvPractical
            plotCQI2(simParameters,CSIReport_perfect, CSIReport_prac,perc)
            if Save_to_File
                saveas(gcf, fullfile(fullResultsPath, 'CQI2.png'));
            end
        
            plotRank2(simParameters,CSIReport_perfect, CSIReport_prac,perc)
            if Save_to_File
                saveas(gcf, fullfile(fullResultsPath, 'RI2.png'));
            end
        end
    end
    
    % --- 4. 视觉诊断原始数据 (用于复现星座图和 H 矩阵) ---
    if Plot_Constellation
        simResults.ConstellationResults = ConstellationResults;
        simResults.HestResults = HestResults;
    end
    
    if strcmpi(CQIMode, "Subband")
        SNRIn = simParameters.SNRIn;             
        
        % 差分映射表 (3GPP TS 38.214)
        offsetMap = [0, 1, 2, -1];
        
        % 过滤掉不存在于仿真序列中的 SNR 点
        validSNRs = intersect(CQI_Investigation_SNR, SNRIn, 'stable');
        numValid = length(validSNRs);
        
        % 创建画布
        figure('Color', 'w', 'Name', 'Subband CQI Snapshots (Strict Match)');
        tlo = tiledlayout(numValid, 1, 'TileSpacing', 'Compact');
        
        for i = 1:numValid
            target = validSNRs(i);
            
            % 精确寻找索引
            idx = find(SNRIn == target, 1);
            
            % 提取该 SNR 下的所有 Slot 数据
            currentSNRReports = CSIReport{idx};
            
            % 固定选取每个 SNR 下的第一个时刻 (或者你可以改为 randi)
            slotIdx = 5; 
            report = currentSNRReports(slotIdx);
            
            % 还原物理 CQI
            raw = double(report.CQI);
            wbCQI = raw(1);
            diffs = raw(2:end);
            actualSubbandCQIs = wbCQI + offsetMap(diffs + 1);
            numSB = length(actualSubbandCQIs);
            
            simResults.stats.subbandCQI(i).SNR = target;
            simResults.stats.subbandCQI(i).SlotIdx = slotIdx;
            simResults.stats.subbandCQI(i).WidebandCQI = wbCQI;
            simResults.stats.subbandCQI(i).PhysicalSubbandCQI = actualSubbandCQIs;
            % 绘图部分
            nexttile;
            % 绘制阶梯图，为了让最后一个子带显示完整，末尾补齐
            plot(1:numSB, actualSubbandCQIs, '-o', 'LineWidth', 2, 'MarkerSize', 5, ...
                'MarkerFaceColor', [0.1 0.3 0.6], 'Color',[0.1 0.3 0.6]);
            
            hold on;
            % 画出 Wideband 参考线
            yline(wbCQI, '--k', sprintf('WB=%d', wbCQI), 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'right');
            
            % 细节装饰
            grid on;
            set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.5);
            ylim([0 16]); % CQI 范围 0-15，留一点顶部空间
            xlim([1 numSB+1]);
            ylabel('Physical CQI');
            title(sprintf('Exact SNR: %.1f dB | Slot Index: %d', target, slotIdx), 'FontSize', 10);
            
            % 只在最后一张图显示横坐标
            if i < numValid
                set(gca, 'XTickLabel', {});
            else
                xlabel('Subband Index');
                xticks(1.5 : 1 : numSB+0.5); % 让刻度对准阶梯中间
                xticklabels(1:numSB);
            end
        end   
        title(tlo, 'Comparison of Subband Frequency Selectivity at Specific SNRs', 'FontSize', 12);
        if Save_to_File
            saveas(gcf, fullfile(fullResultsPath, 'SubbandCQI.png'));
        end
    end 
    
    occupiedBW = simParameters.Carrier.NSizeGrid * 12 * simParameters.Carrier.SubcarrierSpacing * 1e3;

    %simResults.CQI=cellfun(@(x) median([x.CQI]), CSIReport);
    % Bundle key parameters and results into a combined structure for recording
    simResults.Settings.simParameters = simParameters;
    simResults.Stats.simThroughput = simThroughput;
    simResults.Stats.maxThroughput = maxThroughput;
    simResults.Stats.Throughput= 100* simThroughput./maxThroughput;
    simResults.CSI.CSIReport = CSIReport;
    simResults.Stats.log_tcr_mean=log_tcr_mean;
    simResults.Stats.log_layer_mean=log_layer_mean;
    simResults.Stats.Mbps=1e-6*simThroughput/(simParameters.NFrames*10e-3);
    simResults.Stats.SE = simThroughput / (simParameters.NFrames * 10e-3 * occupiedBW);
    
    %flattended version
    simResults.Stats.log_tcr_f=log_tcr_f;
    simResults.Stats.log_layer_f=log_layer_f;
    simResults.Stats.log_slot_f=vertcat(log_slot{:});
    simResults.Stats.log_mod_f=vertcat(log_mod{:});
    
    simResults.Settings.snrVals = snrVals;
    
    % --- 3. CSI 对比原始数据 (Perfect vs Practical) ---
    if CQI_PrefectvPractical
        simResults.CSI.CSIReport_perfect = CSIReport_perfect;
        simResults.CSI.CSIReport_prac = CSIReport_prac;
        simResults.Settings.CQI_Investigation_SNR = CQI_Investigation_SNR; % 记录调查了哪些 SNR
    end
    
    
    if Save_to_File
        save(fullfile(fullResultsPath, [filename, '.mat']), 'simResults', '-v7.3');
        disp("File Saved successfully")
    end   
        
    disp("End of the simulation");
    %exit
    close all;
end

%-----------------------------------------------------All functions used
function [carrier,eDLSCH,pdsch,pdschextra,csirs,wtx] = setupTransmitter(simParameters)
% Extract channel and signal-level parameters, create DL-SCH encoder, and
% initialize MIMO precoding matrix.

    carrier = simParameters.Carrier;
    pdsch = simParameters.PDSCH;
    pdschextra = simParameters.PDSCHExtension;
    csirs = simParameters.CSIRS;

    % Select XOverhead for TBS calculation if required
    if isempty(pdschextra.XOverhead)
        pdschextra.XOverhead = getXOverhead(carrier,csirs);
    end
    
    % Create DL-SCH encoder system object to perform transport channel
    % encoding
    eDLSCH = nrDLSCH;

    % Initialize MIMO precoding matrix
    wtx = 1;
    
end

function [decodeDLSCH,timingOffset,N0,noiseEst,csiReports,csiAvailableSlots] = setupReceiver(simParameters,channel,snrIdx,csiFeedbackOpts)
% Create and configure DL-SCH decoder. Obtain noise related quantities and
% initial CSI feedback from perfect channel knowledge.

    % Create DL-SCH decoder system object to perform transport channel
    % decoding
    decodeDLSCH = nrDLSCHDecoder;
    decodeDLSCH.LDPCDecodingAlgorithm = simParameters.PDSCHExtension.LDPCDecodingAlgorithm;
    decodeDLSCH.MaximumLDPCIterationCount = simParameters.PDSCHExtension.MaximumLDPCIterationCount;

    % Calculate noise standard deviation. Normalize noise power by the IFFT
    % size used in OFDM modulation, as the OFDM modulator applies this
    % normalization to the transmitted waveform.
    carrier = simParameters.Carrier;
    waveInfo = nrOFDMInfo(carrier);
    SNRdB = simParameters.SNRIn(snrIdx);
    SNR = 10^(SNRdB/10);    
    N0 = 1/sqrt(double(waveInfo.Nfft)*SNR);

    % Also normalize by the number of receive antennas if the channel
    % applies this normalization to the output
    chInfo = info(channel);
    if channel.NormalizeChannelOutputs
        if contains(simParameters.DelayProfile,'TDL')
            N0 = N0/sqrt(chInfo.NumReceiveAntennas);
        else 
            N0 = N0/sqrt(chInfo.NumOutputSignals);
        end
    end

    % Initial channel estimate
    [Hest,timingOffset] = getInitialChannelEstimate(carrier,channel,chInfo.MaximumChannelDelay);

    % Initial noise variance
    noiseEst = N0^2*double(waveInfo.Nfft);

    % Obtain an initial CSI report based on perfect channel estimates that
    % the Tx can use to adapt the transmission parameters.
    csirs = simParameters.CSIRS;

    % Initial CSI report using initial channel estimate
    csiFeedbackOpts.PerfectChannelEstimator = true;
    csirs.CSIRSPeriod = 'on';
    csiReports = hCSIEncode(carrier,csirs,Hest,noiseEst,csiFeedbackOpts);
    csiAvailableSlots = 0;

end

function channel = createChannel(simParameters)
% Create and configure the propagation channel. If the number of antennas
% is 1, configure only 1 polarization, otherwise configure 2 polarizations.

    % Number of antenna elements and polarizations
    nTxAnts = simParameters.NTxAnts;
    numTxPol = 1 + (nTxAnts>1);
    nRxAnts = simParameters.NRxAnts;
    numRxPol = 1 + (nRxAnts>1);
    
    if contains(simParameters.DelayProfile,'CDL')

        % Create CDL channel
        channel = nrCDLChannel;

        % Tx antenna array configuration in CDL channel. The number of antenna
        % elements depends on the panel dimensions. The size of the antenna
        % array is [M,N,P,Mg,Ng]. M and N are the number of rows and columns in
        % the antenna array. P is the number of polarizations (1 or 2). Mg and
        % Ng are the number of row and column array panels respectively. Note
        % that N1 and N2 in the panel dimensions follow a different convention
        % and denote the number of columns and rows, respectively.
        txArray = simParameters.TransmitAntennaArray;
        M = txArray.PanelDimensions(2);
        N = txArray.PanelDimensions(1);
        Ng = txArray.NumPanels;

        channel.TransmitAntennaArray.Size = [M N numTxPol 1 Ng];
        channel.TransmitAntennaArray.ElementSpacing = [0.5 0.5 1 1]; % Element spacing in wavelengths
        channel.TransmitAntennaArray.PolarizationAngles = [-45 45];  % Polarization angles in degrees
        
        % Rx antenna array configuration in CDL channel
        rxArray = simParameters.ReceiveAntennaArray;
        M = rxArray.PanelDimensions(2);
        N = rxArray.PanelDimensions(1);
        Ng = rxArray.NumPanels;

        channel.ReceiveAntennaArray.Size = [M N numRxPol 1 Ng];
        channel.ReceiveAntennaArray.ElementSpacing = [0.5 0.5 1 1];  % Element spacing in wavelengths
        channel.ReceiveAntennaArray.PolarizationAngles = [0 90];     % Polarization angles in degrees

    elseif contains(simParameters.DelayProfile,'TDL')

        channel = nrTDLChannel;
        channel.NumTransmitAntennas = nTxAnts;
        channel.NumReceiveAntennas = nRxAnts;

    else

        error('Channel not supported.')

    end

    % Configure common channel parameters: delay profile, delay spread, and
    % maximum Doppler shift
    channel.DelayProfile = simParameters.DelayProfile;
    channel.DelaySpread = simParameters.DelaySpread;
    channel.MaximumDopplerShift = simParameters.MaximumDopplerShift;

    % Configure the channel to return the OFDM response
    channel.ChannelResponseOutput = 'ofdm-response';

    % Get information about the baseband waveform after OFDM modulation step
    waveInfo = nrOFDMInfo(simParameters.Carrier);

    % Update channel sample rate based on carrier information
    channel.SampleRate = waveInfo.SampleRate;
    
end

function [channel,maxChannelDelay] = setupChannel(simParameters)
% Reset propagation channel and obtain the maximum channel delay

    % Extract carrier and channel
    channel = simParameters.Channel;
    channel.reset();

    % Get the channel information
    chInfo = info(channel);
    maxChannelDelay = chInfo.MaximumChannelDelay;

end

function [ofdmResponse,toffset] = getInitialChannelEstimate(carrier,channel,maxChannelDelay)
% Obtain OFDM channel response and timing offset before first transmission.
% This can be used to obtain initial transmission parameters.

    % Clone channel and configure channel to get OFDM channel response for
    % one slot
    channel = clone(channel);
    release(channel);
    channel.ChannelFiltering = false;
    ofdmInfo = nrOFDMInfo(carrier);
    channel.NumTimeSamples = (ofdmInfo.SampleRate*1e-3/carrier.SlotsPerSubframe) + maxChannelDelay;
    [ofdmResponse,toffset] = channel(carrier);
    
end

function XOverhead = getXOverhead(carrier,csirs)
% Calculate XOverhead for transport block size determination based on
% CSI-RS resource grid occupancy

    [~,csirsInfo] = nrCSIRSIndices(carrier,csirs);
    csirsRE = length(csirsInfo.KBarLBar{1})*length(csirsInfo.KPrime{1})*length(csirsInfo.LPrime{1});
    [~,XOverhead] = quantiz(csirsRE,[0 6 12],[0 6 12 18]);
    
    if csirsRE > XOverhead
        warning("The CSI-RS RE overhead is higher than the maximum 18. This can result in decoding failures.")
    end

end

function cdmLengths = getCSIRSCDMLengths(csirs)
%   CDMLENGTHS = getCSIRSCDMLengths(CSIRS) returns the CDM lengths given
%   the CSI-RS configuration object CSIRS.

    CDMType = csirs.CDMType;
    if ~iscell(csirs.CDMType)
        CDMType = {csirs.CDMType};
    end
    CDMTypeOpts = {'noCDM','fd-CDM2','CDM4','CDM8'};
    CDMLengthOpts = {[1 1],[2 1],[2 2],[2 4]};
    cdmLengths = CDMLengthOpts{strcmpi(CDMTypeOpts,CDMType{1})};

end

function csiFeedbackOpts = getCSIFeedbackOptions(simParameters,snrIdx)
% Create a CSI feedback algorithmic options structure

    csiFeedbackOpts = struct();
    csiFeedbackOpts.CSIReportMode = simParameters.CSIReportMode;
    csiFeedbackOpts.CSIReportPeriod = simParameters.CSIReportConfig.Period;
    csiFeedbackOpts.CSIReportConfig = simParameters.CSIReportConfig;
    csiFeedbackOpts.PerfectChannelEstimator = simParameters.PerfectChannelEstimator;
    csiFeedbackOpts.DMRSConfig = simParameters.PDSCH.DMRS;
    
    if simParameters.CSIReportMode == "AI CSI compression"
        % Copy additional link adaptation configuration for AI CSI compression mode
        csiFeedbackOpts.AINetworkFilename = simParameters.AINetworkFilename;
    
        % Download and extract a pretrained CSI network for AI CSI compression mode
        displayProgress = (snrIdx==1);
        helperCSINetDownloadData(displayProgress);
    end

end

function panelDimensions = getCSIReportPanelDimensions(antennaArray,codebookType)
% Configure the antenna array dimensions according to TS 38.214 Section
% 5.2.2.2 as a vector [N1,N2] for single-panel arrays and a vector
% [Ng,N1,N2] for multi-panel arrays.

    panelDimensions = antennaArray.PanelDimensions;
    
    % Add number of panels if codebook type is multi-panel
    if strcmpi(codebookType,'Type1MultiPanel')
        panelDimensions = [antennaArray.NumPanels panelDimensions];
    end
end

function csislot = nextCSISlot(period,nslot)
% Return the slot number of the first slot where CSI feedback can be
% reported according to the CSI report periodicity

    p = period(1); % Slot periodicity
    o = period(2); % Slot offset

    csislot = p*ceil((nslot-o)/p)+o;

end

function numElemenets = numAntennaElements(antArray)
% Calculate number of antenna elements in an antenna array

    numElemenets = antArray.NumPolarizations*antArray.NumPanels*prod(antArray.PanelDimensions);
    
end

function ranks = updateRankRestriction(dmrsConfig,CSIReportConfig)
% Restrict ranks unsupported by the DM-RS configuration
    ranks = CSIReportConfig.RIRestriction;
    
    if ~dmrsConfig.DMRSEnhancedR18 && (dmrsConfig.DMRSLength == 1) && strcmpi(CSIReportConfig.CodebookType, 'Type1SinglePanel')
        if (dmrsConfig.DMRSConfigurationType == 1)
            % Up to rank 4 for DM-RS configuration type 1
            dmrsRankRestriction = [ones(1,4) zeros(1,4)];
        else
            % Up to rank 6 for DM-RS configuration type 2
            dmrsRankRestriction = [ones(1,6) zeros(1,2)];
        end

        if isempty(ranks)
            ranks = ones(1,8);
        end

        ranks = ranks.*dmrsRankRestriction;

        fprintf('The PDSCH DM-RS configuration limits the maximum number of layers to %d. \n',find(dmrsRankRestriction,1,'last'));
    end
end

function validateCSIRSConfig(carrier,csirs,nTxAnts)
% validateCSIRSConfig(CARRIER,CSIRS,NTXANTS) validates the CSI-RS
% configuration, given the carrier specific configuration object CARRIER,
% CSI-RS configuration object CSIRS, and the number of transmit antennas
% NTXANTS.

    % Validate the number of CSI-RS ports
    if ~isscalar(unique(csirs.NumCSIRSPorts))
        error('nr5g:InvalidCSIRSPorts',...
            'All the CSI-RS resources must be configured to have the same number of CSI-RS ports.');
    end

    % Validate the CSI-RS and TX antenna array configuration
    if any(csirs.Ports_Options(csirs.RowNumber) ~= nTxAnts)
        rn = num2str(find(csirs.Ports_Options == nTxAnts),'%3d,');
        str = 'The number of CSI-RS ports must be equal to the number of Tx antenna elements. ';
        str = [str sprintf('For the Tx antenna array size configured, valid CSI-RS row numbers are (%s).',rn(1:end-1))];
        error(str)
    end

    % Validate the CDM lengths
    if ~iscell(csirs.CDMType)
        cdmType = {csirs.CDMType};
    else
        cdmType = csirs.CDMType;
    end
    if (~all(strcmpi(cdmType,cdmType{1})))
        error('nr5g:InvalidCSIRSCDMTypes',...
            'All the CSI-RS resources must be configured to have the same CDM lengths.');
    end
    if nTxAnts ~= csirs.NumCSIRSPorts(1)
        error('nr5g:InvalidNumTxAnts',['Number of transmit antennas (' num2str(nTxAnts)...
            ') must be equal to the number of CSI-RS ports (' num2str(csirs.NumCSIRSPorts(1)) ').']);
    end

    % Check for the overlap between the CSI-RS indices
    csirsInd = nrCSIRSIndices(carrier,csirs,"OutputResourceFormat",'cell');
    numRes = numel(csirsInd);
    csirsIndAll = cell(1,numRes);
    ratioVal = csirs.NumCSIRSPorts(1)/prod(getCSIRSCDMLengths(csirs));
    for resIdx = 1:numRes
        if ~isempty(csirsInd{resIdx})
            grid = nrResourceGrid(carrier,csirs.NumCSIRSPorts(1));
            [~,tempInd] = nrExtractResources(csirsInd{resIdx},grid);
            if numel(tempInd)/numel(csirsInd{resIdx}) ~= ratioVal
                error('nr5g:OverlappedCSIRSREsSingleResource',['CSI-RS indices of resource '...
                    num2str(resIdx) ' must be unique. Try changing the symbol or subcarrier locations.']);
            end
            csirsIndAll{resIdx} = tempInd(:);
            for idx = 1:resIdx-1
                overlappedInd = ismember(csirsIndAll{idx},csirsIndAll{resIdx});
                if any(overlappedInd)
                    error('nr5g:OverlappedCSIRSREsMultipleResources',['The resource elements of the '...
                        'configured CSI-RS resources must not overlap. Try changing the symbol or '...
                        'subcarrier locations of CSI-RS resource ' num2str(idx) ' and resource ' num2str(resIdx) '.']);
                end
            end
        end
    end
end

function displaySNRPointProgress(simParameters,snrIdx)
% Print SNR point progress

    str = ['\nSimulating transmission scheme 1 (%dx%d) and '...  
          'SCS=%dkHz with %s channel at %gdB SNR for %d 10ms frame(s)\n' ...
          'Using %s as CSI feedback.\n'];

    switch simParameters.CSIReportMode
        case 'RI-PMI-CQI'
            modeText = 'RI, PMI, and CQI';
        case 'AI CSI compression'
            modeText = 'compressed channel estimates';
        otherwise 
            modeText = 'channel estimates';
    end

    SNRdB = simParameters.SNRIn(snrIdx);
    fprintf(str,simParameters.NTxAnts,simParameters.NRxAnts,simParameters.Carrier.SubcarrierSpacing, ...
        simParameters.DelayProfile,SNRdB,simParameters.NFrames,modeText);

end

function printSlotInfo(NSlots,carrier,pdsch,pdschextra,blkerr,ECR,csirsTransmission,csiReports,reportIndex)
% Print information about the current slot transmission

    ncw = pdsch.NumCodewords;
    cwLayers = floor((pdsch.NumLayers + (0:ncw-1)) / ncw);
    infoStr = [];
    for cwIdx = 1:ncw
        if blkerr(cwIdx)
            infoStrCW = "Transmission failed";
        else
            infoStrCW = "Transmission succeeded";
        end
        infoStrCW = sprintf("%22s (Layers=%d, Mod=%5s, TCR=%.3f, CR=%.3f).",infoStrCW,cwLayers(cwIdx),pdsch.Modulation{cwIdx},pdschextra.TargetCodeRate(cwIdx),ECR(cwIdx));
        if (ncw>1)
            infoStr = sprintf('%s\n%s%s',infoStr,sprintf('CW%d: %s',cwIdx-1),infoStrCW);
        else
            infoStr = infoStrCW;
        end
    end
    
    csirsInfoStr = [];
    if csirsTransmission
        csirsInfoStr = "CSI-RS transmission. ";
    end

    csifbInfoStr = [];
    if carrier.NSlot == 0
        csifbInfoStr = 'Using initial CSI.';
    elseif reportIndex > 0
        csifbInfoStr = sprintf("Using CSI from NSlot=%2d.",csiReports(reportIndex).NSlot);
    end

    nslot = carrier.NSlot;
    fprintf('\n(%5.2f%%) NSlot=%2d: %s',100*(nslot+1)/NSlots,nslot,join([infoStr,csifbInfoStr,csirsInfoStr]));

end


function plotLayerEVM(NSlots,nslot,pdsch,siz,pdschIndices,pdschSymbols,pdschEqSymbols)
% Plot EVM information

    persistent slotEVM;
    persistent rbEVM
    persistent evmPerSlot;
    persistent numLayers;
    
    maxNumLayers = 8;
    if (nslot==0)
        slotEVM = comm.EVM;
        rbEVM = comm.EVM;
        evmPerSlot = NaN(NSlots,maxNumLayers);
        numLayers = pdsch.NumLayers;
        figure;
    else
        % Keep the maximum number of layers in the legend
        numLayers = max(numLayers,pdsch.NumLayers);
    end
    [Ns,P] = size(pdschEqSymbols);
    pdschEqSym = zeros(Ns,maxNumLayers);
    pdschSym = zeros(Ns,maxNumLayers);
    pdschEqSym(:,1:P) = pdschEqSymbols;    
    pdschSym(:,1:P) = pdschSymbols;
    evmPerSlot(nslot+1,:) = slotEVM(pdschSym,pdschEqSym);
    subplot(2,1,1);
    plot(0:(NSlots-1),evmPerSlot,'o-');
    xlabel('Slot number');
    ylabel('EVM (%)');
    legend("layer " + (1:numLayers),'Location','EastOutside');
    title('EVM per layer per slot');

    subplot(2,1,2);
    [k,~,p] = ind2sub(siz,pdschIndices);
    rbsubs = floor((k-1) / 12);
    NRB = siz(1) / 12;
    evmPerRB = NaN(NRB,maxNumLayers);
    for nu = 1:pdsch.NumLayers
        for rb = unique(rbsubs).'
            this = (rbsubs==rb & p==nu);
            evmPerRB(rb+1,nu) = rbEVM(pdschSym(this),pdschEqSym(this));
        end
    end

    plot(0:(NRB-1),evmPerRB,'x-');
    xlabel('Resource block');
    ylabel('EVM (%)');
    legend("layer " + (1:numLayers),'Location','EastOutside');
    title(['EVM per layer per resource block, slot #' num2str(nslot)]);
    
    drawnow;
    
end

function statsTable = plotCQI(simParameters,CSIReport,perc)
% Plot CQI median and percentiles 

    % Calculate median and percentiles
    med = cellfun(@(x) median([x.CQI]), CSIReport);
    p1 = cellfun(@(x) prctile([x.CQI],50-perc/2), CSIReport);
    p2 = cellfun(@(x) prctile([x.CQI],50+perc/2), CSIReport);
    
    % Calculate the percentage of CQI not in the set {median CQI -1, median CQI, median CQI +1} 
    cqiPerc = cellfun(@(x,y) sum(abs([x.CQI]-y)>1)/length(x),CSIReport,num2cell(med));
    
    statsTable = table(simParameters.SNRIn(:), med(:), p1(:), p2(:), cqiPerc(:)*100, ...
        'VariableNames', {'SNR_dB', 'Median_CQI', 'Lower_Bound', 'Upper_Bound', 'Deviation_Pct'});

    figure('Name','CQI vs SNR', ...
       'NumberTitle','off');
    subplot(211)
    errorbar(simParameters.SNRIn,med,p2-p1,'o-.')
    ylabel('CQI value')
    title(sprintf('Median CQI and (%g,%g) Percentiles',50-perc/2,50+perc/2));
    grid

    subplot(212)
    plot(simParameters.SNRIn,cqiPerc,'o-.')
    xlabel('SNR (dB)')
    ylabel('%')
    title('CQI not in set \{median CQI -1, median CQI, median CQI +1\}');
    grid   

end

function plotCQI2(simParameters, CSIReportPerfect, CSIReportPrac, perc)
% plotCQI2: 对比绘制 Perfect 和 Practical 报告的 CQI 中位数及离散度
% simParameters.SNRIn: 横轴 SNR 向量
% perc: 百分位数范围 (例如 90 代表 5% 和 95%)4
    offset = 0.2;
    
    % --- 处理 Perfect Report ---
    med1 = cellfun(@(x) median([x.CQI]), CSIReportPerfect);
    p1_1 = cellfun(@(x) prctile([x.CQI], 50-perc/2), CSIReportPerfect);
    p2_1 = cellfun(@(x) prctile([x.CQI], 50+perc/2), CSIReportPerfect);
    % 计算偏差率
    cqiPerc1 = cellfun(@(x,y) sum(abs([x.CQI]-y)>1)/length(x), CSIReportPerfect, num2cell(med1));

    % --- 处理 Practical Report ---
    med2 = cellfun(@(x) median([x.CQI]), CSIReportPrac);
    p1_2 = cellfun(@(x) prctile([x.CQI], 50-perc/2), CSIReportPrac);
    p2_2 = cellfun(@(x) prctile([x.CQI], 50+perc/2), CSIReportPrac);
    % 计算偏差率
    cqiPerc2 = cellfun(@(x,y) sum(abs([x.CQI]-y)>1)/length(x), CSIReportPrac, num2cell(med2));

    % --- 获取 SNR 轴 ---
    snr_axis = simParameters.SNRIn;
    snr_min = min(snr_axis) - offset;
    snr_max = max(snr_axis) + offset;
    figure('Name', 'CQI Perfect vs Practical', 'NumberTitle', 'off', 'Color', 'w');
    
    % Subplot 1: Median and Percentiles
    subplot(2,1,1)
    % Perfect: 蓝色圆圈实线
    errorbar(snr_axis-offset/2, med1, med1-p1_1, p2_1-med1, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6); hold on;
    % Practical: 红色方块虚线
    errorbar(snr_axis+offset/2, med2, med2-p1_2, p2_2-med2, 'r--s', 'LineWidth', 1.2, 'MarkerSize', 6);
    
    ylabel('CQI Value')
    title(sprintf('Median CQI and (%g, %g) Percentiles', 50-perc/2, 50+perc/2));
    legend('Perfect', 'Practical', 'Location', 'best');
    grid on;
    xlim([snr_min, snr_max]);
    % Subplot 2: Out-of-range Percentage
    subplot(2,1,2)
    plot(snr_axis, cqiPerc1*100, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6); hold on;
    plot(snr_axis, cqiPerc2*100, 'r--s', 'LineWidth', 1.2, 'MarkerSize', 6);
    
    xlabel('SNR (dB)')
    ylabel('Deviation (%)')
    title('CQI Deviation: % of samples not in {median \pm 1}');
    legend('Perfect', 'Practical', 'Location', 'best');
    grid on;
    xlim([snr_min, snr_max]);
end

function statsTable = plotSubbandCQI(simParameters, CSIReport, perc)
% PLOTSUBBANDCQI 还原差分 CQI 并进行统计（修正语法错误版）

    % --- 1. 计算各项统计指标 ---
    % 每一个 cellfun 内部嵌套 arrayfun 处理 26 个 slot 的结构体数组
    
    % 计算真实 CQI 均值
    subMean = cellfun(@(x) mean(arrayfun(@(s) mean(decodeActualCQI(s.CQI)), x)), CSIReport);
    
    % 计算物理跨度 (Range)
    subRange = cellfun(@(x) mean(arrayfun(@(s) calculateRange(s.CQI), x)), CSIReport);
    
    % 计算偏离度 (Deviation)
    devPerc = cellfun(@(x) mean(arrayfun(@(s) calculateDev(s.CQI), x)), CSIReport);
    
    % --- 2. 后续统计与绘图 ---
    med = subMean; 
    statsTable = table(simParameters.SNRIn(:), med(:), subRange(:), devPerc(:)*100, ...
        'VariableNames', {'SNR_dB', 'True_Mean_CQI', 'True_Physical_Range', 'Deviation_Pct'});

    figure('Name', 'True Subband CQI Analysis', 'NumberTitle', 'off');
    subplot(211)
    plot(simParameters.SNRIn, subMean, 's-', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
    ylim([0 15]);
    ylabel('Real Physical CQI (Mean)');
    title('True Average CQI (Wideband + Subband Offsets) vs SNR');
    grid on;

    subplot(212)
    yyaxis left
    bar(simParameters.SNRIn, subRange);
    ylabel('Physical CQI Spread (Max-Min)');
    yyaxis right
    plot(simParameters.SNRIn, devPerc*100, 'ro-', 'MarkerFaceColor', 'r');
    ylabel('Subband Deviation (%)');
    xlabel('SNR (dB)');
    title('Frequency Selectivity & Subband Deviation');
    legend('Avg Physical Spread', 'Avg Deviation %');
    grid on;
end

%% --- 局部辅助函数 (Local Functions) ---

function actualVals = decodeActualCQI(rawCQI)
    % 将 [Wideband; Diff1; Diff2...] 还原为物理 CQI 数组
    raw = double(rawCQI);
    wb = raw(1);
    % 差分映射: 0->0, 1->+1, 2->+2, 3->-1
    offsets = [0, 1, 2, -1];
    % 还原所有子带值 (raw(2:end) 是索引，+1 匹配 MATLAB 1-based 索引)
    subbands = wb + offsets(raw(2:end) + 1);
    % 结果包含 wideband 和还原后的 subbands
    actualVals = [wb; subbands(:)];
end

function r = calculateRange(rawCQI)
    vals = decodeActualCQI(rawCQI);
    % 只计算子带部分的物理跨度
    if length(vals) > 1
        subPart = vals(2:end);
        r = max(subPart) - min(subPart);
    else
        r = 0;
    end
end

function d = calculateDev(rawCQI)
    vals = decodeActualCQI(rawCQI);
    if length(vals) > 1
        subPart = vals(2:end);
        % 计算偏离子带均值超过 1 的比例
        d = sum(abs(subPart - mean(subPart)) > 1) / length(subPart);
    else
        d = 0;
    end
end

function statsTable = plotRank(simParameters, CSIReport, perc)
% plotRank2: 对比绘制 Perfect 和 Practical 报告的 RI (Rank Index) 中位数及离散度
% simParameters.SNRIn: 横轴 SNR 向量
% perc: 百分位数范围 (例如 90 代表 5% 和 95%)

    offset = 0.2; % 绘图偏移，防止误差棒重叠

    % --- 处理 Perfect Report ---
    % 假设字段名为 RI，如果你的数据结构里是 Rank，请将 .RI 改为 .Rank
    med = cellfun(@(x) median([x.RI]), CSIReport);
    p1 = cellfun(@(x) prctile([x.RI], 50-perc/2), CSIReport);
    p2 = cellfun(@(x) prctile([x.RI], 50+perc/2), CSIReport);

    statsTable = table(simParameters.SNRIn(:), med(:), p1(:), p2(:), ...
        'VariableNames', {'SNR_dB', 'Median_RI', 'Lower_Bound', 'Upper_Bound'});
    % --- 获取 SNR 轴 ---
    snr_axis = simParameters.SNRIn;
    snr_min = min(snr_axis) - offset;
    snr_max = max(snr_axis) + offset;
    figure('Name', 'Rank Perfect vs Practical', 'NumberTitle', 'off', 'Color', 'w');
    
    % Perfect: 蓝色圆圈实线
    errorbar(snr_axis-offset/2, med, med-p1, p2-med, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6); hold on;
    
    ylabel('Rank Value (RI)')
    title(sprintf('Median RI and (%g, %g) Percentiles', 50-perc/2, 50+perc/2));
    legend('Perfect', 'Practical', 'Location', 'best');
    grid on;
    xlim([snr_min, snr_max]);
    ylim([max(0, min(p1)-0.5), 4]);
end

function plotRank2(simParameters, CSIReportPerfect, CSIReportPrac, perc)
% plotRank2: 对比绘制 Perfect 和 Practical 报告的 RI (Rank Index) 中位数及离散度
% simParameters.SNRIn: 横轴 SNR 向量
% perc: 百分位数范围 (例如 90 代表 5% 和 95%)

    offset = 0.2; % 绘图偏移，防止误差棒重叠

    % --- 处理 Perfect Report ---
    % 假设字段名为 RI，如果你的数据结构里是 Rank，请将 .RI 改为 .Rank
    med1 = cellfun(@(x) median([x.RI]), CSIReportPerfect);
    p1_1 = cellfun(@(x) prctile([x.RI], 50-perc/2), CSIReportPerfect);
    p2_1 = cellfun(@(x) prctile([x.RI], 50+perc/2), CSIReportPerfect);
    % 计算偏差率 (RI 偏离中位数超过 1 的比例)
    rankPerc1 = cellfun(@(x,y) sum(abs([x.RI]-y)>1)/length(x), CSIReportPerfect, num2cell(med1));

    % --- 处理 Practical Report ---
    med2 = cellfun(@(x) median([x.RI]), CSIReportPrac);
    p1_2 = cellfun(@(x) prctile([x.RI], 50-perc/2), CSIReportPrac);
    p2_2 = cellfun(@(x) prctile([x.RI], 50+perc/2), CSIReportPrac);
    % 计算偏差率
    rankPerc2 = cellfun(@(x,y) sum(abs([x.RI]-y)>1)/length(x), CSIReportPrac, num2cell(med2));

    % --- 获取 SNR 轴 ---
    snr_axis = simParameters.SNRIn;
    snr_min = min(snr_axis) - offset;
    snr_max = max(snr_axis) + offset;
    figure('Name', 'Rank Perfect vs Practical', 'NumberTitle', 'off', 'Color', 'w');
    
    % Subplot 1: Median and Percentiles
    subplot(2,1,1)
    % Perfect: 蓝色圆圈实线
    errorbar(snr_axis-offset/2, med1, med1-p1_1, p2_1-med1, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6); hold on;
    % Practical: 红色方块虚线
    errorbar(snr_axis+offset/2, med2, med2-p1_2, p2_2-med2, 'r--s', 'LineWidth', 1.2, 'MarkerSize', 6);
    
    ylabel('Rank Value (RI)')
    title(sprintf('Median RI and (%g, %g) Percentiles', 50-perc/2, 50+perc/2));
    legend('Perfect', 'Practical', 'Location', 'best');
    grid on;
    xlim([snr_min, snr_max]);
    ylim([min([med1, med2])-1, max([med1, med2])+1]); % 优化显示范围

    % Subplot 2: Out-of-range Percentage
    subplot(2,1,2)
    plot(snr_axis, rankPerc1*100, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6); hold on;
    plot(snr_axis, rankPerc2*100, 'r--s', 'LineWidth', 1.2, 'MarkerSize', 6);
    
    xlabel('SNR (dB)')
    ylabel('Deviation (%)')
    title('Rank Deviation: % of samples not in {median \pm 1}');
    legend('Perfect', 'Practical', 'Location', 'best');
    grid on;
    xlim([snr_min, snr_max]);
end

function ranklimit=rankrestrictionfromRI(RI)
    if all(RI == 1)
        ranklimit = "0";
    else
        onesPositions = find(RI == 1);  
        ranklimit = strjoin(arrayfun(@num2str, onesPositions, 'UniformOutput', false), '');
    end
end

function sym = getConstellationPoints(Modulation, NumCodewords)
%getConstellationPoints Constellation points
%   SYM = getConstellationPoints(PDSCH) returns the constellation points
%   SYM based on modulation schemes provided in PDSCH configuration object.

    sym = [];
    modulation = string(Modulation);  % Convert modulation scheme to string type
    ncw = NumCodewords;               % Number of codewords
    if ncw == 2 && isscalar(modulation)
        modulation(end+1) = modulation(1);
    end
    % Get the constellation points
    for cwIndex = 1:ncw
        qm = strcmpi(modulation(cwIndex),{'QPSK','16QAM','64QAM','256QAM'})*[2 4 6 8]';
        sym = [sym; nrSymbolModulate(int2bit((0:2^qm-1)',qm),modulation(cwIndex))]; %#ok<AGROW>
    end

end

function plotWidebandCQIAndSINR(cqiPracticalPerSlot,cqiPerfectPerSlot,SINRPerSubbandPerCWPractical,SINRPerSubbandPerCWPerfect,activeSlotNum)
%   Plots the wideband SINR and wideband CQI values for each codeword
%   across all specified active slots (1-based) (in which the CQI is
%   reported as other than NaN) for practical and perfect channel
%   estimation cases.

    % Check if there are no slots in which NZP-CSI-RS is present
    if isempty(activeSlotNum)
        disp('No CQI data to plot, because there are no slots in which NZP-CSI-RS is present.');
        return;
    end
    cqiPracticalPerCW = permute(cqiPracticalPerSlot(1,:,:),[1 3 2]);
    cqiPerfectPerCW = permute(cqiPerfectPerSlot(1,:,:),[1 3 2]);
    SINRPerCWPractical = permute(SINRPerSubbandPerCWPractical(1,:,:),[1 3 2]);
    SINRPerCWPerfect = permute(SINRPerSubbandPerCWPerfect(1,:,:),[1 3 2]);

    % Extract wideband CQI indices for slots where NZP-CSI-RS is present
    cqiPracticalPerCWActiveSlots = cqiPracticalPerCW(1,activeSlotNum,:);
    cqiPerfectPerCWActiveSlots = cqiPerfectPerCW(1,activeSlotNum,:);
    widebandSINRPractical = 10*log10(SINRPerCWPractical(1,activeSlotNum,:));
    widebandSINRPerfect = 10*log10(SINRPerCWPerfect(1,activeSlotNum,:));

    if isempty(reshape(cqiPracticalPerCWActiveSlots(:,:,1),1,[]))
        disp('No CQI data to plot, because all CQI values are NaNs.');
        return;
    end

    figure();
    plotWBCQISINR(widebandSINRPerfect,widebandSINRPractical,211,activeSlotNum,'SINR');
    plotWBCQISINR(cqiPerfectPerCWActiveSlots,cqiPracticalPerCWActiveSlots,212,activeSlotNum,'CQI');
end

function plotSubbandCQIAndSINR(subbandCQIPractical,subbandCQIPerfect,SINRPerCWPractical,SINRPerCWPerfect,activeSlotNum,nslot)
%   Plots the SINR and CQI values for each codeword across all the subbands
%   for practical and perfect channel estimation cases for the given slot
%   number (0-based) among all specified active slots (1-based). The
%   function does not plot the values if CQIMode is 'Wideband' or if the
%   CQI and SINR values are all NaNs in the given slot.

    % Check if there are no slots in which NZP-CSI-RS is present
    if isempty(activeSlotNum)
        disp('No CQI data to plot, because there are no slots in which NZP-CSI-RS is present.');
        return;
    end
    numSubbands = size(subbandCQIPractical,1);
    if numSubbands > 1 && ~any(nslot+1 == activeSlotNum) % Check if the CQI values are reported in the specified slot
        disp(['For the specified slot (' num2str(nslot) '), CQI values are not reported. Please choose another slot number.']);
        return;
    end

    % Plot subband CQI values
    if numSubbands > 1 % Subband mode
        subbandCQIPerCWPractical = subbandCQIPractical(2:end,:,nslot+1);
        subbandCQIPerCWPerfect = subbandCQIPerfect(2:end,:,nslot+1);
        subbandSINRPerCWPractical = 10*log10(SINRPerCWPractical(2:end,:,nslot+1));
        subbandSINRPerCWPerfect = 10*log10(SINRPerCWPerfect(2:end,:,nslot+1));
        figure();
        plotSBCQISINR(subbandSINRPerCWPerfect,subbandSINRPerCWPractical,numSubbands,211,nslot,'SINR')
        plotSBCQISINR(subbandCQIPerCWPerfect,subbandCQIPerCWPractical,numSubbands,212,nslot,'CQI');
    end
end

function plotSBCQISINR(perfectVals,practicalVals,numSubbands,subplotIdx,nslot,inpText)
%   Plots the SINR and CQI values for each codeword across all the subbands
%   for practical and perfect channel estimation cases for the given slot
%   number (0-based). The function does not plot the values if CQIMode is
%   'Wideband' or if the CQI and SINR values are all NaNs in the given
%   slot.

    subplot(subplotIdx)
    plot(perfectVals(:,1),'ro-');
    hold on;
    plot(practicalVals(:,1),'b*-');
    if ~all(isnan(perfectVals(:,2))) % Two codewords
        hold on;
        plot(perfectVals(:,2),'rs:');
        hold on;
        plot(practicalVals(:,2),'bd:');
        legend({'Codeword 1:Perfect channel est.','Codeword 1:Practical channel est.','Codeword 2:Perfect channel est.','Codeword 2:Practical channel est.'});
        title(['Estimated Subband ' inpText ' Values for Codeword 1&2 in Slot ' num2str(nslot)]);
    else % Single codeword
        legend({'Codeword 1:Perfect channel est.','Codeword 1:Practical channel est.'});
        title(['Estimated Subband ' inpText ' Values for Codeword 1 in Slot ' num2str(nslot)]);
    end

    if strcmpi(inpText,'SINR')
        units = ' in dB';
    else
        units = '';
    end
    xlabel('Subbands');
    ylabel(['Subband ' inpText ' Values' units]);
    xticks(1:numSubbands);
    xTickLables = num2cell(1:numSubbands);
    xticklabels(xTickLables);
    xlim([0 numSubbands+1]);
    [lowerBound,upperBound] = bounds([perfectVals(:);practicalVals(:)]);
    ylim([lowerBound-1 upperBound+3.5]);
end

function plotType1PMIAndRI(pmiPracticalPerSlot,pmiPerfectPerSlot,riPracticalPerSlot,riPerfectPerSlot,activeSlotNum,nslot)
%   Plots the RI and PMI i1 indices across all specified active slots
%   (1-based), for practical and perfect channel estimation scenarios. The
%   function also plots the i2 indices of practical and perfect channel
%   estimation scenarios across all specified active slots when the PMI
%   mode is 'Wideband' or plots i2 indices across all the subbands for the
%   specified slot number (0-based) when the PMI mode is 'Subband'.

    % Check if there are no slots in which NZP-CSI-RS is present
    if isempty(activeSlotNum)
        disp('No PMI and RI data to plot, because there are no slots in which NZP-CSI-RS is present.');
        return;
    end
    
    numi1Indices = numel(pmiPracticalPerSlot(activeSlotNum(1)).i1);
    if numi1Indices == 6
        codebookType = 'Type1MultiPanel';
    else
        codebookType = 'Type1SinglePanel';
    end
    
    % Extract wideband PMI indices (i1 values) for slots where NZP-CSI-RS
    % is present
    i1PerfectValsActiveSlots = reshape([pmiPerfectPerSlot(activeSlotNum).i1],numi1Indices,[])';
    i1PracticalValsActiveSlots = reshape([pmiPracticalPerSlot(activeSlotNum).i1],numi1Indices,[])';
    
    if isempty(i1PerfectValsActiveSlots)
        disp('No PMI and RI data to plot, because all PMI and RI values are NaNs.');
        return;
    end
    
    figure;
    % Plot RI
    plotRI(riPracticalPerSlot,riPerfectPerSlot,activeSlotNum,411);
    
    % Extract and plot i11 indices
    i11PerfectVals = i1PerfectValsActiveSlots(:,1);
    i11PracticalVals = i1PracticalValsActiveSlots(:,1);
    plotIxxIndices(i11PerfectVals,i11PracticalVals,activeSlotNum,412,'i11');

    % Extract and plot i12 indices
    i12PerfectVals = i1PerfectValsActiveSlots(:,2);
    i12PracticalVals = i1PracticalValsActiveSlots(:,2);
    plotIxxIndices(i12PerfectVals,i12PracticalVals,activeSlotNum,413,'i12');

    % Extract and plot i13 indices
    i13PerfectVals = i1PerfectValsActiveSlots(:,3);
    i13PracticalVals = i1PracticalValsActiveSlots(:,3);
    plotIxxIndices(i13PerfectVals,i13PracticalVals,activeSlotNum,414,'i13');
    
    % Plot the i141, i142 and i143 indices in type I multi-panel case
    if strcmpi(codebookType,'Type1MultiPanel')
        figure()
        % Extract and plot i141 indices
        i141PerfectVals = i1PerfectValsActiveSlots(:,4);
        i141PracticalVals = i1PracticalValsActiveSlots(:,4);
        plotIxxIndices(i141PerfectVals,i141PracticalVals,activeSlotNum,311,'i141');

        % Extract and plot i142 indices
        i142PerfectVals = i1PerfectValsActiveSlots(:,5);
        i142PracticalVals = i1PracticalValsActiveSlots(:,5);
        plotIxxIndices(i142PerfectVals,i142PracticalVals,activeSlotNum,312,'i142');
    
        % Extract and plot i143 indices
        i143PerfectVals = i1PerfectValsActiveSlots(:,6);
        i143PracticalVals = i1PracticalValsActiveSlots(:,6);
        plotIxxIndices(i143PerfectVals,i143PracticalVals,activeSlotNum,313,'i143');
    end

    % Get the number of subbands
    numSubbands = size(pmiPracticalPerSlot(activeSlotNum(1)).i2,2);
    % Get the number of i2 indices according to codebook type
    numi2Indices = 1;
    if strcmpi(codebookType,'Type1MultiPanel')
        numi2Indices = 3;
    end

    % Get number of active slots
    numActiveSlots = numel(activeSlotNum);
    % Extract i2 values
    i2PerfectVals = reshape([pmiPerfectPerSlot(activeSlotNum).i2],[numSubbands,numi2Indices,numActiveSlots]);     % Of size numActiveSlots-by-numi2Indices-numSubbands
    i2PracticalVals = reshape([pmiPracticalPerSlot(activeSlotNum).i2],[numSubbands,numi2Indices,numActiveSlots]); % Of size numActiveSlots-by-numi2Indices-numSubbands

    % Plot i2 values
    if numSubbands == 1 % Wideband mode
        figure;

        % In type I single-panel case, there is only one i2 index. The
        % first column of i2PerfectVals and i2PracticalVals corresponds to
        % i2 index. In type I multi-panel case, the i2 values are a set of
        % three indices i20, i21, and i22. Each column of i2PerfectVals and
        % i2PracticalVals correspond to i20, i21, and i22 indices. Extract
        % and plot the respective index values
        if strcmpi(codebookType,'Type1SinglePanel')
            % Extract and plot i2 values in each slot
            i2PerfectVals = reshape(i2PerfectVals(:,1,:),[],numActiveSlots).';
            i2PracticalVals = reshape(i2PracticalVals(:,1,:),[],numActiveSlots).';
            plotIxxIndices(i2PerfectVals,i2PracticalVals,activeSlotNum,111,'i2');
        else
            % Extract and plot i20 values in each slot
            i20PerfectVals = reshape(i2PerfectVals(:,1,:),[],numActiveSlots).';
            i20PracticalVals = reshape(i2PracticalVals(:,1,:),[],numActiveSlots).';
            plotIxxIndices(i20PerfectVals,i20PracticalVals,activeSlotNum,311,'i20');

            % Extract and plot i21 values in each slot
            i21PerfectVals = reshape(i2PerfectVals(:,2,:),[],numActiveSlots).';
            i21PracticalVals = reshape(i2PracticalVals(:,2,:),[],numActiveSlots).';
            plotIxxIndices(i21PerfectVals,i21PracticalVals,activeSlotNum,312,'i21');

            % Extract and plot i22 values in each slot
            i22PerfectVals = reshape(i2PerfectVals(:,3,:),[],numActiveSlots).';
            i22PracticalVals = reshape(i2PracticalVals(:,3,:),[],numActiveSlots).';
            plotIxxIndices(i22PerfectVals,i22PracticalVals,activeSlotNum,313,'i22');
        end
    else % Subband mode
        if any(nslot+1 == activeSlotNum)
    
            % In subband mode, plot the PMI i2 indices corresponding to the
            % specified slot number
            figure;

            if strcmpi(codebookType,'Type1SinglePanel')
                % Extract and plot i2 values
                pmiSBi2Perfect = pmiPerfectPerSlot(nslot+1).i2(1,:);
                pmiSBi2Practical = pmiPracticalPerSlot(nslot+1).i2(1,:);
                plotI2xIndices_SB(pmiSBi2Perfect,pmiSBi2Practical,numSubbands,nslot,111,'i2');
            else
                % Extract and plot i20 values
                pmiSBi20Perfect = pmiPerfectPerSlot(nslot+1).i2(1,:);
                pmiSBi20Practical = pmiPracticalPerSlot(nslot+1).i2(1,:);
                plotI2xIndices_SB(pmiSBi20Perfect,pmiSBi20Practical,numSubbands,nslot,311,'i20');
                
                % Extract and plot i21 values
                pmiSBi21Perfect = pmiPerfectPerSlot(nslot+1).i2(2,:);
                pmiSBi21Practical = pmiPracticalPerSlot(nslot+1).i2(2,:);
                plotI2xIndices_SB(pmiSBi21Perfect,pmiSBi21Practical,numSubbands,nslot,312,'i21');
    
                % Extract and plot i22 values
                pmiSBi22Perfect = pmiPerfectPerSlot(nslot+1).i2(3,:);
                pmiSBi22Practical = pmiPracticalPerSlot(nslot+1).i2(3,:);
                plotI2xIndices_SB(pmiSBi22Perfect,pmiSBi22Practical,numSubbands,nslot,313,'i22');
            end
        else
            disp(['For the specified slot (' num2str(nslot) '), PMI i2 indices are not reported. Please choose another slot number.'])
        end
    end
end

function plotType2PMIAndRI(pmiPracticalPerSlot,pmiPerfectPerSlot,riPracticalPerSlot,riPerfectPerSlot,panelDims,numBeams,activeSlotNum,nslot)
%   Plots the grid of beams by highlighting the beams that are used for the
%   precoding matrix generation for the specified slot number (0-based),
%   for practical and perfect channel estimation scenarios.

    % Check if there are no slots in which NZP-CSI-RS is present
    if isempty(activeSlotNum)
        disp('No PMI and RI data to plot, because there are no slots in which NZP-CSI-RS is present.');
        return;
    end
    plotRI(riPracticalPerSlot,riPerfectPerSlot,activeSlotNum,111);
    if ~any(nslot+1 == activeSlotNum)
        disp(['For the specified slot (' num2str(nslot) '), PMI values are not reported. Please choose another slot number.']);
    else
        pmiPractical = pmiPracticalPerSlot(nslot+1);
        pmiPerfect = pmiPerfectPerSlot(nslot+1);
        figure();
        plotType2GridOfBeams(pmiPractical,panelDims,numBeams,'Practical Channel Estimation Scenario',1);
        hold on;
        plotType2GridOfBeams(pmiPerfect,panelDims,numBeams,'Perfect Channel Estimation Scenario',2);
    end
end

function plotRI(riPracticalPerSlot,riPerfectPerSlot,activeSlotNum,subplotIndex)
%   Plots the RI values across all specified active slots (1-based), for
%   practical and perfect channel estimation scenarios.

    % Get number of active slots
    numActiveSlots = numel(activeSlotNum);

    % Extract RI values for slots where NZP-CSI-RS is present
    RIPerfectValsActiveSlots = riPerfectPerSlot(activeSlotNum)';
    RIPracticalValsActiveSlots = riPracticalPerSlot(activeSlotNum)';
    
    if isempty(RIPerfectValsActiveSlots)
        disp('No RI data to plot, because all RI values are NaNs.');
        return;
    end
    
    figure;
    subplot(subplotIndex);
    plot(RIPerfectValsActiveSlots,'r-o');
    hold on;
    plot(RIPracticalValsActiveSlots,'b-*');
    xlabel('Slots')
    ylabel('RI Values');
    xticks(1:numActiveSlots);
    xTickLables = num2cell(activeSlotNum(:)-1);
    xticklabels(xTickLables);
    [~,upperBound] = bounds([RIPerfectValsActiveSlots; RIPracticalValsActiveSlots]);
    xlim([0 numActiveSlots+8]);
    ylim([0 upperBound+1]);
    yticks(0:upperBound+1);
    title('RI Values')
    legend({'Perfect channel est.','Practical channel est.'});
end

function plotType2GridOfBeams(PMISet,panelDims,numBeams,chEstType,subplotNum)
%   Plots the grid of beams by highlighting the beams that are used for the
%   type II codebook based precoding matrix generation.

    N1 = panelDims(1);
    N2 = panelDims(2);    
    % Get the oversampling factors
    O1 = 4;
    O2 = 1 + 3*(N2 ~= 1);

    % Extract q1, q2 values
    qSet = PMISet.i1(1:2);
    q1 = qSet(1)-1;
    q2 = qSet(2)-1;

    % Extract i12 value
    i12 = PMISet.i1(3);
    s = 0;
    % Find the n1, n2 values for all the beams, as defined in TS 38.214
    % Section 5.2.2.2.3
    n1_i12 = zeros(1,numBeams);
    n2_i12 = zeros(1,numBeams);
    for beamIdxI = 0:numBeams-1
        i12minussVal = i12 - s;
        xValues = numBeams-1-beamIdxI:N1*N2-1-beamIdxI;
        CValues = zeros(numel(xValues),1);
        for xIdx = 1:numel(xValues)
            if xValues(xIdx) >= numBeams-beamIdxI
                CValues(xIdx) = nchoosek(xValues(xIdx),numBeams-beamIdxI);
            end
        end
        indices = i12minussVal >= CValues;
        maxIdx = find(indices,1,'last');
        xValue = xValues(maxIdx);
        ei = CValues(maxIdx);
        s = s+ei;
        ni = N1*N2 - 1 - xValue;
        n1_i12(beamIdxI+1) = mod(ni,N1);
        n2_i12(beamIdxI+1) = (ni-n1_i12(beamIdxI+1))/N1;
    end
    m1 = O1*(0:N1-1) + q1;
    m2 = O2*(0:N2-1) + q2;

    % Calculate the indices of orthogonal basis set which corresponds to
    % the reported i12 value
    m1_LBeams = O1*(n1_i12) + q1;
    m2_LBeams = O2*(n2_i12) + q2;
    OrthogonalBeams = [repmat(m1,1,length(m2));reshape(repmat(m2,length(m1),1),1,[])]';

    % Plot the grid of beams
    numCirlcesInRow = N1*O1;
    numCirlcesInCol = N2*O2;
    subplot(2,1,subplotNum);
    circleRadius = 1;
    for colIdx = 0:numCirlcesInCol-1
        for rowIdx = 0:numCirlcesInRow-1
            p = nsidedpoly(1000, 'Center', [2*rowIdx 2*colIdx], 'Radius', circleRadius);
            if any(prod(OrthogonalBeams == [rowIdx colIdx],2))
                h2 = plot(p, 'FaceColor', 'w','EdgeColor','r','LineWidth',2.5);
                hold on;
                if any(prod([m1_LBeams' m2_LBeams'] == [rowIdx colIdx],2))
                    h3 = plot(p, 'FaceColor', 'g','LineStyle','-.');                
                end
            else
                h1 = plot(p, 'FaceColor', 'w');
            end
            hold on;
        end
    end
    rowLength = 2*circleRadius*O1;
    colLength = 2*circleRadius*O2;
    for n2 = 0:N2-1
        for n1 = 0:N1-1
            x1 = -1*circleRadius + rowLength*n1;
            x2 = x1 + rowLength;
            y1 = -1*circleRadius + colLength*n2;
            y2 = y1 + colLength;
            x = [x1, x2, x2, x1, x1];
            y = [y1, y1, y2, y2, y1];
            plot(x, y, 'b-', 'LineWidth', 2);
            hold on;
        end
    end
    
    xlabel('N1O1 beams');
    ylabel('N2O2 beams');
    axis equal;
    set(gca,'xtick',[],'ytick',[]);
    legend([h1 h2 h3],{'Oversampled DFT beams',['Orthogonal basis set with [q1 q2] = [' num2str(q1) ' ' num2str(q2) ']'],'Selected beam group'},'Location','northeast');
    title(['Grid of Beams or DFT Vectors for ' chEstType]);
end

function plotIxxIndices(ixxPerfectVals,ixxPracticalVals,activeSlotNum,subplotInp,pmiIdxType)
%   Plots i11, i12, i13 indices in case of type I single-panel codebooks
%   and plots i141, i142, and i143 in case of type I multi-panel codebooks.

    % Plot ixx values
    subplot(subplotInp)
    plot(ixxPerfectVals,'r-o');
    hold on;
    plot(ixxPracticalVals,'b-*');
    xlabel('Slots')
    ylabel([pmiIdxType ' Indices']);
    % Get number of active slots
    numActiveSlots = numel(activeSlotNum);
    xticks(1:numActiveSlots);
    xTickLables = num2cell(activeSlotNum(:)-1);
    xticklabels(xTickLables);
    [lowerBound,upperBound] = bounds([ixxPerfectVals; ixxPracticalVals]);
    xlim([0 numActiveSlots+8]);
    ylim([lowerBound-2 upperBound+2]);
    title(['PMI: ' pmiIdxType ' Indices']);
    legend({'Perfect channel est.','Practical channel est.'});
end

function plotI2xIndices_SB(pmiSBi2Perfect,pmiSBi2Practical,numSubbands,nslot,subplotInp,pmiIdxType)
%   Plots i2 indices in case of type I single-panel codebooks and plots
%   i20, i21, and i22 in case of type I multi-panel codebooks.

    subplot(subplotInp)
    plot(pmiSBi2Perfect,'r-o');
    hold on;
    plot(pmiSBi2Practical,'b-*');
    title(['PMI: ' pmiIdxType ' Indices for All Subbands in Slot ' num2str(nslot)]);
    xlabel('Subbands')
    ylabel([pmiIdxType ' Indices']);
    xticks(1:numSubbands);
    xticklabels(num2cell(1:numSubbands));
    [lowerBound,upperBound] = bounds([pmiSBi2Perfect pmiSBi2Practical]);
    yticks(lowerBound:upperBound);
    yticklabels(num2cell(lowerBound:upperBound));
    xlim([0 numSubbands+1])
    ylim([lowerBound-1 upperBound+1]);
    legend({'Perfect channel est.','Practical channel est.'});
end