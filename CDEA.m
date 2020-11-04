% =====================================================================
% Code for conference paper:
% Cross-domain error adaptation for unsupervised domain adaptation, ICDM2020
% By Fengli Cui, Yinghao Chen, MF1933011@smail.nju.edu.cn
% =====================================================================
function [acc, acc_per_class] = CDEA(domainS_features,domainS_labels,domainT_features,domainT_labels,d,T,options)
num_iter = T;
options.ReducedDim = d;
options.alpha = 1;

num_class = length(unique(domainS_labels));
W_all = zeros(size(domainS_features,1)+size(domainT_features,1));
W_s = constructW1(domainS_labels);
W = W_all;
W(1:size(W_s,1),1:size(W_s,2)) =  W_s;
% looping
p = 1;
predLabels = [];
pseudoLabels = [];
for iter = 1:num_iter
	% ����P�����function
    P = constructP(domainS_features,domainS_labels,domainT_features,pseudoLabels, W,options);
    domainS_proj = domainS_features*P;
    domainT_proj = domainT_features*P;
    proj_mean = mean([domainS_proj;domainT_proj]);
    domainS_proj = domainS_proj - repmat(proj_mean,[size(domainS_proj,1) 1 ]);
    domainT_proj = domainT_proj - repmat(proj_mean,[size(domainT_proj,1) 1 ]);
    domainS_proj = L2Norm(domainS_proj);
    domainT_proj = L2Norm(domainT_proj);
    %% distance to class means
    classMeans = zeros(num_class,options.ReducedDim);
    for i = 1:num_class
        classMeans(i,:) = mean(domainS_proj(domainS_labels==i,:));
    end
    classMeans = L2Norm(classMeans);
    distClassMeans = EuDist2(domainT_proj,classMeans);
    targetClusterMeans = vgg_kmeans(double(domainT_proj'), num_class, classMeans')';
    targetClusterMeans = L2Norm(targetClusterMeans);
    distClusterMeans = EuDist2(domainT_proj,targetClusterMeans);
    expMatrix = exp(-distClassMeans);
    expMatrix2 = exp(-distClusterMeans);
    probMatrix1 = expMatrix./repmat(sum(expMatrix,2),[1 num_class]);
    probMatrix2 = expMatrix2./repmat(sum(expMatrix2,2),[1 num_class]);
    
    probMatrix = probMatrix1 * (1-iter./num_iter) + probMatrix2 * iter./num_iter;
    [prob,predLabels] = max(probMatrix');
    
    %% ��ѡp1��p2Ԥ��classһ������
    [~,I1] = max(probMatrix1');
    [~,I2] = max(probMatrix2');
    samePredict = find(I1 == I2); % P1 P2Ԥ����ȵ��±꼯��
    prob1 = prob(samePredict);  % ȡ����ЩԤ��һ�������ĸ���
    predLabels1 = predLabels(samePredict);  % ȡ����ЩԤ��һ��������Ԥ���ǩ
    
    p=iter/num_iter;
    p = max(p,0);
    [sortedProb,index] = sort(prob1);  % ��Ԥ��һ��������Ԥ��������򣬵õ���index��ӦsamePredict���±�
    sortedPredLabels = predLabels1(index);
    trustable = zeros(1,length(prob1));
    %% ��ÿ�����а���Ԥ����������ƽ��˼����ѡ����
    for i = 1:num_class
        ntc = length(find(predLabels==i));
        ntc_same = length(find(predLabels1 == i));
        % Ҫ��Ԥ��һ���������ҵ�ǰclass��ע�����indexҪһ�£����ڶ���samePredict�е��±�
        thisClassProb = sortedProb(sortedPredLabels==i);
        if length(thisClassProb)>0
            %��ÿ�����а���Ԥ����������ƽ��˼����ѡ��min(iter/num_iter * nc, sameDc)������
            minProb = thisClassProb(max(ntc_same-(floor(p*ntc)+1) , 1));
            % �ҳ�Ԥ��һ��������Ԥ��ֵ������СԤ����ֵ��������ע�⣬�õ�����samePredict�е��±�
            trustable = trustable+ (prob1>minProb).*(predLabels1==i);
        end
    end
    % �ҵ�������ӦĿ����������index
    true_index = samePredict(trustable==1);
    pseudoLabels = predLabels;
    trustable = zeros(1, length(prob));
    trustable(true_index) = 1;
    pseudoLabels(~trustable) = -1;
    
    W = constructW1([domainS_labels,pseudoLabels]);
	% ----------------------------------------
    %% calculate ACC
    acc(iter) = sum(predLabels==domainT_labels)/length(domainT_labels);
    for i = 1:num_class
        acc_per_class(iter,i) = sum((predLabels == domainT_labels).*(domainT_labels==i))/sum(domainT_labels==i);
    end
    fprintf('Iteration=%d/%d, Acc:%0.3f,Mean acc per class: %0.3f\n', iter,num_iter, acc(iter), mean(acc_per_class(iter,:)));
    if sum(trustable)>=length(prob)
        break;
    end
end
