function result = Update_SUE_DF()

% ### 编辑人：张雅倩 ###
% ### 最后编辑时间：2018.06.22 ###
% 代码作用：
% 对东方证券《业绩超预期类因子》这篇研报进行重现，计算上市公司的预期外净利润数据(SUE0)，通过公司的回测平台回测后发现，业绩超预期类因子有很好的选股效果，可以作为alpha因子纳入多因子选股体系
% 主要解决的问题是财务数据在时间轴上的对齐问题。A股的上市公司有四个报告期（一季报，二季报，三季报，年报），在财务报表发布后上市公司依旧会对已发布的报表进行调整更正，如何保证数据是当期可得，不引入未来信息是关键

w = windmatlab;
% 从公司因子库中提取以下数据：Tradedate、交易日期的数值型、股票代码的数值型
load 【Update】FactorStore.mat Tradedate Tradedatenum Stocknum;

% 将股票代码排序，并制作上司公司报告期时间表quarter_table，便于之后的数据查找
Stocknum = sort(Stocknum);
quarter_table = w.tdays(Tradedate{1},Tradedate{end},'Days=Alldays;Period=Q');
quarter_table = cell2mat(cellfun(@(x) str2double(datestr(x,'yyyymmdd')),quarter_table,'UniformOutput',false));

% 导入wind中提取的Net profit数据，制作出表格tmp_np，其中第一列为股票代码，第二列为上市公司财报的报告期(格式为数值型，例如:'2015/12/31'为20151231)，第三列为上市公司财报的具体发布日期(格式同上)，第四列为净利润
fd = fopen('NetProfit.txt');
dat = textscan(fd, '%f%f%f%s','headerlines',1); 
fclose(fd);
tmp_np = table(dat{1, 1}, dat{1, 2}, dat{1, 3}, str2double(dat{1, 4}), 'VariableNames', {'stk', 'rdate', 'issuedate', 'NP'});
% 对股票代码、报告期时间、发布日期先后进行排序
tmp_np = sortrows(tmp_np, 1:3);
tmp_np = tmp_np(table2array(tmp_np(:, 1)) > 0, :); 
tmp_np = tmp_np(table2array(tmp_np(:,2)) > 20031231,:);
tmp_np = table2array(tmp_np);
uniquestock = unique(tmp_np(:,1));

% 通过差分计算单季度净利润数据seasonal_np
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
            % 确保使用的上一期的净利润数据是当期可得，避免引入未来信息
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

% 获取填充位置表:Numeric
Numeric = nan(length(Tradedatenum),length(Stocknum));
for id1 = 1:length(Stocknum)
    idx = find(allstock==Stocknum(id1));
    for id2 = 1:length(idx)
        tmpbegin_id=find(Tradedatenum>=allissuedate(idx(id2)),1)+1;
        % Numeric中每次出现新的报告期覆盖，则取第一行为正，其余为负，方便SUE_DF的计算，减少程序运算量
        Numeric(tmpbegin_id:end,id1) = -allreportdate(idx(id2));
        Numeric(tmpbegin_id,id1) = allreportdate(idx(id2));
    end
end

% 逐点计算SUE_DF
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
                
                % 获取最新的过去12期单季度净利润数据
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

% 填充SUE_DF数据
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
