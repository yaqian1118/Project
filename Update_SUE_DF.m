function result = Update_SUE_DF()

% ### �༭�ˣ�����ٻ ###
% ### ���༭ʱ�䣺2018.06.22 ###
% �������ã�
% �Զ���֤ȯ��ҵ����Ԥ�������ӡ���ƪ�б��������֣��������й�˾��Ԥ���⾻��������(SUE0)��ͨ����˾�Ļز�ƽ̨�ز���֣�ҵ����Ԥ���������кܺõ�ѡ��Ч����������Ϊalpha�������������ѡ����ϵ
% ��Ҫ����������ǲ���������ʱ�����ϵĶ������⡣A�ɵ����й�˾���ĸ������ڣ�һ�����������������������걨�����ڲ��񱨱��������й�˾���ɻ���ѷ����ı�����е�����������α�֤�����ǵ��ڿɵã�������δ����Ϣ�ǹؼ�

w = windmatlab;
% �ӹ�˾���ӿ�����ȡ�������ݣ�Tradedate���������ڵ���ֵ�͡���Ʊ�������ֵ��
load ��Update��FactorStore.mat Tradedate Tradedatenum Stocknum;

% ����Ʊ�������򣬲�������˾��˾������ʱ���quarter_table������֮������ݲ���
Stocknum = sort(Stocknum);
quarter_table = w.tdays(Tradedate{1},Tradedate{end},'Days=Alldays;Period=Q');
quarter_table = cell2mat(cellfun(@(x) str2double(datestr(x,'yyyymmdd')),quarter_table,'UniformOutput',false));

% ����wind����ȡ��Net profit���ݣ����������tmp_np�����е�һ��Ϊ��Ʊ���룬�ڶ���Ϊ���й�˾�Ʊ��ı�����(��ʽΪ��ֵ�ͣ�����:'2015/12/31'Ϊ20151231)��������Ϊ���й�˾�Ʊ��ľ��巢������(��ʽͬ��)��������Ϊ������
fd = fopen('NetProfit.txt');
dat = textscan(fd, '%f%f%f%s','headerlines',1); 
fclose(fd);
tmp_np = table(dat{1, 1}, dat{1, 2}, dat{1, 3}, str2double(dat{1, 4}), 'VariableNames', {'stk', 'rdate', 'issuedate', 'NP'});
% �Թ�Ʊ���롢������ʱ�䡢���������Ⱥ��������
tmp_np = sortrows(tmp_np, 1:3);
tmp_np = tmp_np(table2array(tmp_np(:, 1)) > 0, :); 
tmp_np = tmp_np(table2array(tmp_np(:,2)) > 20031231,:);
tmp_np = table2array(tmp_np);
uniquestock = unique(tmp_np(:,1));

% ͨ����ּ��㵥���Ⱦ���������seasonal_np
seasonal_np = nan(size(tmp_np));
count = 0;
for id1 = 1:length(uniquestock)
    tmpdata = tmp_np(tmp_np(:,1)==uniquestock(id1),:);
    tmpdata2 = tmpdata;
    tmpdata2(:,end) = nan;
    for id2 = 1:size(tmpdata,1)
        tmpdate = mod(tmpdata(id2,2),10000);
        if  tmpdate ~= 331
            idx = find(quarter_table == tmpdata(id2,2))-1;
            % ȷ��ʹ�õ���һ�ڵľ����������ǵ��ڿɵã���������δ����Ϣ
            idj = find(tmpdata(:,2) == quarter_table(idx) & tmpdata(:,3) <= tmpdata(id2,3),1,'last');
            if ~isempty(idj)
                tmpdata2(id2,4) = tmpdata(id2,4) - tmpdata(idj,4);
            end
        else
            tmpdata2(id2,4) = tmpdata(id2,4);
        end
    end
    seasonal_np(count+1:count+size(tmpdata2,1),:) = tmpdata2;
    count = count+size(tmpdata2,1);
end

 
allstock = seasonal_np(:,1);
allreportdate = seasonal_np(:,2);
allissuedate = seasonal_np(:,3);
delete_index1 = find(~ismember(allstock,Stocknum));
delete_index2 = find(allreportdate<20031230);
delete_index = union(delete_index1,delete_index2);
allstock(delete_index) = [];
allissuedate(delete_index) = [];
allreportdate(delete_index) = [];

% ��ȡ���λ�ñ�:Numeric
Numeric = nan(length(Tradedatenum),length(Stocknum));
for id1 = 1:length(Stocknum)
    idx = find(allstock==Stocknum(id1));
    for id2 = 1:length(idx)
        tmpbegin_id=find(Tradedatenum>=allissuedate(idx(id2)),1)+1;
        % Numeric��ÿ�γ����µı����ڸ��ǣ���ȡ��һ��Ϊ��������Ϊ��������SUE_DF�ļ��㣬���ٳ���������
        Numeric(tmpbegin_id:end,id1) = -allreportdate(idx(id2));
        Numeric(tmpbegin_id,id1) = allreportdate(idx(id2));
    end
end

% ������SUE_DF
SUE_DF = nan(size(Numeric));
for id1 = 1:size(Numeric,2)
    tmpdata = seasonal_np(seasonal_np(:,1)==Stocknum(id1),:);
    for id2 = 1:size(Numeric,1)
        if Numeric(id2,id1) > 0
            tmp1 = find(quarter_table == Numeric(id2,id1));
            tmp2 = find(tmpdata(:,2)==Numeric(id2,id1));
            if tmp1 > 11 && ~isempty(tmp2)
                tmp3 = tmpdata(tmp2,:);
                tmpissuedate = tmp3(1,3);
                
                tmpdates = quarter_table(tmp1-11:tmp1);
                cond1 = arrayfun(@(x) ismember(x,tmpdates),tmpdata(:,2));
                cond2 = tmpdata(:,3) <= tmpissuedate;
                tmpid = cond1 & cond2;
                tmpsubdata = tmpdata(tmpid,:);
                
                % ��ȡ���µĹ�ȥ12�ڵ����Ⱦ���������
                tmpseason = nan(12,1);
                for i = 1:length(tmpdates)
                    tmpid = find(tmpsubdata(:,2)==tmpdates(i),1,'last');
                    if ~isempty(tmpid)
                        tmpseason(i,1) = tmpsubdata(tmpid,4);
                    end
                end
                
                c_value = tmpseason(5:end)-tmpseason(1:end-4);
                if sum(~isnan(c_value))>=3/4*length(c_value)
                    c_mean = nanmean(c_value);
                    c_std = nanstd(c_value);
                else
                    c_std = nan;
                end
                SUE_DF(id2,id1) = (tmpseason(end)-(tmpseason(end-4)+c_mean))/c_std;
            end
        end
    end
end

% ���SUE_DF����
for id1 = 1:length(Stocknum)
    for id2 = 1:length(Tradedatenum)
        if ~isnan(SUE_DF(id2,id1)) && id2<length(Tradedatenum)
            endid = find(~isnan(SUE_DF(id2+1:end,id1)),1);
            if ~isempty(endid)
                SUE_DF(id2:id2+endid-1,id1) = SUE_DF(id2,id1);
            else
                SUE_DF(id2:length(Tradedatenum),id1) = SUE_DF(id2,id1);
            end
        end
    end
end
result = SUE_DF;

end
