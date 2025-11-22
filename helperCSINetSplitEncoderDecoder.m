function [encNet,decNet] = helperCSINetSplitEncoderDecoder(net,encEnd)
%helperCSINetSplitEncoderDecoder Split encoder and decoder networks
%   [ENC,DEC] = helperCSINetSplitEncoderDecoder(NET,SL) splits the
%   autoencoder neural network, NET, into an encoder neural network, ENC, 
%   and a decoder neural network, DEC. SL is the name of the last layer of
%   the encoder section in NET. This function also adds a feature input layer as the input
%   layer to the DEC.
%
%   See also CSICompressionAutoencoderExample, helperCSINetDLNetwork.

%   Copyright 2022-2023 The MathWorks, Inc.

encEndIdx = find( {net.Layers.Name} == encEnd );
decStart = net.Layers(encEndIdx+1).Name;
decInputSize = net.Layers(encEndIdx+1).InputSize;

% Find and remove encoder layers from decoder
decLayerNames = {net.Layers(encEndIdx+1:end).Name};
encNet = removeLayers(net, decLayerNames);

% Find and remove decoder layers from encoder
encLayerNames = {net.Layers(1:encEndIdx).Name};
decNet = removeLayers(net, encLayerNames);

% Add a feature input layers to the decoder
decNet = addLayers(decNet, featureInputLayer(decInputSize, Name="Dec_in"));
decNet = connectLayers(decNet, "Dec_in", decStart);

encNet = initialize(encNet);
decNet = initialize(decNet);
end