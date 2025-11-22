function [PMISet, info] = hDLPMIRandom(carrier, csirs, reportConfig, nLayers, Hest, varargin)
% hDLPMIRandom  Randomized PMI selection based on 3GPP Type-1 codebook
%   Like hDLPMISelect, but overwrites the UE-chosen W with a random PMI

  % 1) Run the standard selector
  if isempty(varargin)
    [PMISet,info] = hDLPMISelect(carrier,csirs,reportConfig,nLayers,Hest);
  else
    [PMISet,info] = hDLPMISelect(carrier,csirs,reportConfig,nLayers,Hest,varargin{1});
  end

  % 2) Pull out codebook and dimensions
  CB = info.Codebook;                  % [nPorts × nLayers × i2Len × ...]
  i2Len = size(CB,3);                  % Number of PMI indices (i2)

  % 3) Decide how many PRGs or bands there should be
  if isfield(reportConfig, 'SubbandSize') && ~isempty(reportConfig.SubbandSize)
      rbSize = carrier.NSizeGrid;
      prgSize = reportConfig.SubbandSize;
      nBands = ceil(rbSize / prgSize);   % Force PRG count based on SubbandSize
  else
      nBands = 1;  % Wideband fallback
  end

  % 4) Generate random PMIs
  rng('shuffle');
  randI2 = randi(i2Len, 1, nBands) - 1;

  % 5) Construct W matrices per subband
  info.W = cell(1, nBands);
  for b = 1:nBands
      PMISet.i2(b) = randI2(b) + 1;
      info.W{b} = squeeze(CB(:,:,randI2(b)+1,1,1,1));  % [nTx × nLayers]
  end

  % 6) Return final [nTx × nLayers × nBands] precoder matrix
  info.W = cat(3, info.W{:});
end
