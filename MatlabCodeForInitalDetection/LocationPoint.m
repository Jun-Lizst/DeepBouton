function pointStruct = LocationPoint(img, thetaGauss, volumeThre, pointStruct, initialInd, minR, selectThre, localInd1, localInd2, localSize, localNum)
img = double(img) / 2500; % ֮ǰ��ͼ����uint16�ģ��˴�����һ���� ����double��
binImg = double(img > 0); % ��Ӧ�Ķ�ֵͼ�� double��
sizeImg = size(img);
numVoxel = sizeImg(1) * sizeImg(2) * sizeImg(3);
[yInd, xInd, zInd] = ind2sub(sizeImg, 1 : numVoxel);
yxzInd = [yInd; xInd; zInd];

%% �����ܶ�rho�����ڽ����ܶȵľ���delta
%
binImg1 = binImg(:); % ��ͼһά��
delta1 = zeros(numVoxel, 1); % �������
nearestInd1 = zeros(numVoxel, 1); % ��������Ӧ���ڽ�����
gaussTemplate3D = GenerateGaussFilter3D(thetaGauss); %����ط��������¿���
tempImg = padarray(img, [round(2 * thetaGauss) round(2 * thetaGauss) round(2 * thetaGauss)], 'symmetric');
rho = convn(tempImg, gaussTemplate3D, 'valid'); % ��˹�ܶ�
rho = rho .* binImg;
rho1 = rho(:); % һά��

[~, rhoInd] = sort(rho1, 'descend');
delta1(rhoInd(1)) = 1; % ���ܶ����ĵ�� ��̾�����Ϊ1
nearestInd1(rhoInd(1)) = rhoInd(1); % �ܶ�����Ķ�Ӧ�����ڽ��ĵ�ı����Ϊ����
rhoIndNew = find(binImg1(rhoInd) == 1); %��һ��������̾���Ͷ�Ӧ���ڽ���
if sum(binImg1) > localNum
    rhoPadded = padarray(rho, [(localSize - 1)/2 (localSize - 1)/2 (localSize - 1)/2]);
    ff = @(p) MinDistLocal(p, rhoInd, sizeImg, yxzInd, rhoIndNew, localInd1, localInd2, rhoPadded, localSize);
else
    ff = @(p) MinDist(p, rhoInd, sizeImg, yxzInd, rhoIndNew);
end
[ALPH, BETA] = arrayfun(ff, (2 : length(rhoIndNew)));
delta1(rhoInd(rhoIndNew(2:length(rhoIndNew)))) = ALPH;
nearestInd1(rhoInd(rhoIndNew(2:length(rhoIndNew)))) = BETA;

%% ����ѡȡ��cluster centers�ĸ���
%
cellInd1 = find(delta1 > 0.3 & rho1 > 0.1);
voxelInd = 1 : length(delta1);
voxelInd(delta1==0 | rho1 == 0 |delta1 > 0.3 & rho1>0.1) = [];

delta2 = delta1(voxelInd);
rho2 = rho1(voxelInd);
numGrid =1e3;
matrixGrid = zeros(ceil(max(delta2 * numGrid)) + 1, ceil(max(rho2 * numGrid)) + 1);
for i = 1 : length(delta2)
    tempVar1 = round(delta2(i) * numGrid);
    tempVar2 = round(rho2(i) * numGrid);
    matrixGrid(tempVar1 + 1, tempVar2 + 1) = matrixGrid(tempVar1 + 1, tempVar2 + 1) + 1;
end
gaussTemplate2D = fspecial('gaussian', [11 11], 3);
tempImg1 = padarray(matrixGrid, [5 5], 'symmetric');
tempRho = conv2(tempImg1/max(tempImg1(:)), gaussTemplate2D, 'valid');
rhoRhoDelta = zeros(length(delta2), 1);
for i = 1 : length(delta2)
    tempVar3 = round(delta2(i) * numGrid);
    tempVar4 = round(rho2(i) * numGrid);
    rhoRhoDelta(i) = tempRho(tempVar3 + 1, tempVar4 + 1);
end

cellInd2 = intersect(voxelInd(rhoRhoDelta < 1e-2), find(delta1 >= (selectThre * minR)/norm(sizeImg - 1)));
clusterCenter = union(cellInd2, cellInd1);
numCluster = length(clusterCenter);
tempVar5 = rho1(clusterCenter);
[~, tempVar6] = sort(tempVar5, 'descend');
removedCenter = [];
numRemoved = 0;
for i = 1 : numCluster
    for j = i + 1 : numCluster
        if norm(yxzInd(:, clusterCenter(tempVar6(i))) - yxzInd(:, clusterCenter(tempVar6(j)))) < (selectThre * minR) 
            numRemoved = numRemoved + 1;
            removedCenter(numRemoved) = clusterCenter(tempVar6(j));
        end
    end
end
clusterCenter = union(setdiff(clusterCenter, removedCenter), rhoInd(1));
numCluster = length(clusterCenter);

%%=========================================================================
%% ����������
%
labelCluster = zeros(numVoxel, 1);
for i = 1 : numCluster
    labelCluster(clusterCenter(i)) = i;
end
iter = 0;
maxIter = 100;
while sum(labelCluster ~= 0) < sum(binImg1) && iter < maxIter
    for i = 2 : length(rhoIndNew)
        if labelCluster(rhoInd(rhoIndNew(i))) == 0 && nearestInd1(rhoInd(rhoIndNew(i))) > 0
            labelCluster(rhoInd(rhoIndNew(i))) = labelCluster(nearestInd1(rhoInd(rhoIndNew(i))));
        end
    end
    iter = iter + 1;
end

%%=========================================================================
%% ������ֵ���ԭ���Ŀռ���
%
tempVar7 = 1 : numVoxel;
numPoint = size(pointStruct.center, 1);
pointStruct.center(numPoint + 1 : numPoint + numCluster, :) = bsxfun(@plus, yxzInd(:, clusterCenter)', initialInd - [1 1 1]);
for i = 1 : numCluster
    tempImg2 = logical(reshape(labelCluster == i, sizeImg));
    tempVar12 = tempVar7(tempImg2(:));
    pointStruct.volume(numPoint + i, 1) = numel(tempVar12);
    tempVar8 = yxzInd(:, tempVar12)';
    pointStruct.element{numPoint + i, 1} = bsxfun(@plus, tempVar8, initialInd - [1 1 1]);
    tempVar9 = mean(tempVar8, 1);
    pointStruct.centerRe(numPoint + i, :) = tempVar9 + initialInd - [1 1 1];
    tempImg2 = bwperim(tempImg2);
    tempVar10 = tempVar7(tempImg2(:));
    tempVar11 = yxzInd(:, tempVar10)';
    pointStruct.radius(numPoint + i, 1) = mean(sqrt(sum((bsxfun(@minus, tempVar11, tempVar9)).^2, 2))) + 0.5;
end
tempInd1 = find(pointStruct.volume(numPoint + 1 : numPoint + numCluster, 1) < volumeThre);
tempInd2 = find(pointStruct.volume(numPoint + 1 : numPoint + numCluster, 1) >= volumeThre);
pointStruct.label(numPoint + tempInd1, 1) = -1;
pointStruct.label(numPoint + tempInd2, 1) = 1;

end

