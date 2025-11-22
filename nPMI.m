function n = nPMI(nTx,nLayers)
% nPMI  Number of PMI codewords for Type-1 single-panel (TS 38.214)
%   n = nPMI(nTx,nLayers) returns the number of PMI entries for
%   nTx∈{4,8} CSI-RS ports and nLayers∈{1,2,4,8} layers.

  %--- validate inputs ---
  assert(ismember(nTx,[4 8]),   'nTx must be 4 or 8.');
  assert(ismember(nLayers,[1 2 4 8]), ...
         'nLayers must be one of [1,2,4,8].');
  assert(nLayers<=nTx, 'Layers cannot exceed ports.');

  %--- panel dimensions per TS 38.214 Tbl 5.2.2.2.1-2 ---
  if nTx==4
    N1 = 2;   % #cols in panel
  else
    N1 = 4;
  end
  O1 = 4;     % panel horizontal repetition
  % N2=1,O2=1 for single row, so
  M1 = N1*O1; % total columns
  M2 = 1;     % N2*O2

  %--- count codewords per TS 38.214 Tbl 5.2.2.2.1-(5,6,8,12) ---
  switch nLayers
    case 1
      n = M1*M2 * 3;      % i2 ∈ {0,1,2}
    case 2
      n = M1*M2 * 2;      % i2 ∈ {0,1}
    case 4
      n = M1*M2 * 2 * 2;  % i1,3∈{0,1}, i2∈{0,1}
    case 8
      % only for nTx=8: i1,1∈0…(M1/2−1), i1,3∈0…3, i2∈{0,1}
      n = (M1/2) * M2 * 4 * 2;
  end
end