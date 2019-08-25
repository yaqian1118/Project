function result = Update_SUE_DF()

% ### Editor: Yaqian Zhang ###
% ### Last edited: 2018.06.22 ###
% ### Summer Intern Project ###

% Reproduce the research report of Oriental Securities' "Performance Exceeded Expectations Factor" and calculate the expected net profit data of listed companies (SUE0). 
% After backtesting though our fund's backtest platform, I found that the performance exceeds expectations factor has great stock picking effect, and it can be incorporated into our fund's multi-factor stock picking system as an alpha factor.
% The main problem solved here is the alignment of financial data on the timeline. There are four reporting periods for A-share listed companies (one quarterly report, two quarterly reports, three quarterly reports, and annual reports). 
% After the financial statements are issued, the listed companies will still adjust and correct their published statements. The key is to ensure that the data is available in the current period, and no future information is included

w = windmatlab;
% Extract the following data from our company's factor library: Tradedate, transaction date (numeric type), stock code (numeric type)
load 【Update】FactorStore.mat Tradedate Tradedatenum Stocknum;

% Sort the stock code and create a quarter_table for the company's reporting period, which is convenient for us to do subsequent data searches.
Stocknum = sort(Stocknum);
quarter_table = w.tdays(Tradedate{1},Tradedate{end},'Days=Alldays;Period=Q');
quarter_table = cell2mat(cellfun(@(x) str2double(datestr(x,'yyyymmdd')),quarter_table,'UniformOutput',false));

% Import the Net profit data extracted from the Wind and create the table tmp_np. The first column is the stock code, 
% and the second column is the reporting period of the listed company's financial report (the format is numeric, for example: '2015/12/31' is 20151231)
% The third column is the specific release date of the listed company's financial report (the format is the same as above), and the fourth column is the net profit.
fd = fopen('NetProfit.txt');
dat = textscan(fd, '%f%f%f%s','headerlines',1); 
fclose(fd);
tmp_np = table(dat{1, 1}, dat{1, 2}, dat{1, 3}, str2double(dat{1, 4}), 'VariableNames', {'stk', 'rdate', 'issuedate', 'NP'});
% Sort stock code, reporting period, and release date
tmp_np = sortrows(tmp_np, 1:3);
tmp_np = tmp_np(table2array(tmp_np(:, 1)) > 0, :); 
tmp_np = tmp_np(table2array(tmp_np(:,2)) > 20031231,:);
tmp_np = table2array(tmp_np);
uniquestock = unique(tmp_np(:,1));

% Calculate single-quarter net profit data "seasonal_np" by differential calculations 
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
            % Ensure that the previous period's net profit data is available in the current period, avoiding the future information
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
        % Every time a new report period coverage occurs, make the first row becomes positive and let the rest become negative, 
        % This method can facilitate the calculation of SUE_DF and reduce the time for program operations.
        Numeric(tmpbegin_id:end,id1) = -allreportdate(idx(id2));
        Numeric(tmpbegin_id,id1) = allreportdate(idx(id2));
    end
end

% Calculate SUE_DF point by point
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

% filling SUE_DF data
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
