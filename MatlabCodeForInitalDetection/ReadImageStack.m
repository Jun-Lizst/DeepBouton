function img = ReadImageStack(pathImg, sizeImg)
%%=========================================================================
%% ��ȡһ��stack
%
img = zeros(sizeImg, 'uint16');
parfor i = 1 : sizeImg(3)
    img(:, :, i) = imread(pathImg, i);
end
