function Hvirt = virtualizeChannel(Hfull, W)
% Reduce physical channel H (e.g., [624x14xR x 512]) → virtualized [624x14xR x 8]
    sz = size(Hfull);
    Hfull = reshape(Hfull, [], sz(4));       % [* x 512]
    Hvirt = Hfull * W;                        % [* x 8]
    Hvirt = reshape(Hvirt, sz(1), sz(2), sz(3), size(W,2));  % [K L R 8]
end