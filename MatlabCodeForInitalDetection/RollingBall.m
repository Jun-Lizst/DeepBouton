function img = RollingBall(img, templateRoll)
n = size(img, 3);
parfor i = 1 : n
    temp1 = double(img(:, :, i));
    temp1 = padarray(temp1, [50 50], 'symmetric');
    temp1 = convnFast(temp1, templateRoll, 'valid');%����ģ��ϴ��ʹ��convnFast
    temp1 = convn(padarray(temp1, [2 2], 'symmetric'), ones(5, 5)/25, 'valid');
    img(:, :, i) = max(img(:, :, i) - uint16(temp1), 0);
end

end

