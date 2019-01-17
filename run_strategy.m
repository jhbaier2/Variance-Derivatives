function [PNL] = run_strategy(skew, vix, skew_star, vix_star, option_data, rate_data, tcost)
%input filtered by expir option and rate data
%skew and vix: time series
%skew, vix, skew_star, vix_star, option_data, rate_data, tcost
dates = unique(rate_data.DATETIME);
long_trade_dates = dates((skew.SKEW > skew_star) & (vix.Close < vix_star));
long_trades = option_data(ismember(option_data.DATETIME, long_trade_dates), :); %apply conditions to dates to find where to make trades
long_trade_rates = rate_data(ismember(rate_data.DATETIME, long_trade_dates), :);

%short_trade_dates = dates((skew.SKEW  < skew_star) & (vix.Close > vix_star));
%short_trades = option_data(ismember(option_data.DATETIME, short_trade_dates), :);
%short_trade_rates = rate_data(ismember(option_data.DATETIME, short_trade_dates), :);

pnl_long = trade_long(long_trades, long_trade_rates, rate_data, tcost);
pnl_short = 0
%pnl_short = trade_short(short_trades, short_trade_rates, rate_data, tcost);

PNL = pnl_long + pnl_short;
end

function [tot_returns] = trade_long(opt, rates, all_rates, tcost)

%opt = opt(opt.DATETIME == dates, :); %filter option data to only trading dates
%rate_filtered = rates(rates.DATETIME == dates, :);

returns = 0;
for i = 1:height(rates) %loop through each unique data to find sigma and K
    
   trade_date = rates.DATETIME(i); %get current trade date
   trade_rate = rates(i, :);
   opt_i = opt(opt.DATETIME == trade_date, :);
   k_i = K_Var(opt_i, trade_rate);
   disp(k_i);
   sigmar_i = realized_vol(all_rates, trade_date);
   
   returns_i = sigmar_i - k_i^2 - tcost;
   returns = returns + returns_i;
end

tot_returns = returns;
end

function [tot_returns] = trade_short(opt, rates, tcost)

%opt = opt(opt.DATETIME == dates);
%rate_filtered = rates(rates.DATETIME == dates, :);

returns = 0;
for i = 1:height(rate_filtered)
    
   trade_date = rate_filtered.DATETIME(i);
   opt_i = opt(opt.DATETIME == trade_date, :);
   k_i = K_Var(opt_i, rates);
   sigmar_i = realized_vol(rates, trade_date);
   
   returns_i = -sigmar_i + k_i^2 - tcost;
   returns = returns + returns_i;
end

tot_returns = returns;

end

function [sigma_r] = realized_vol(rates, trade_date)
%input unfilterd arrays by date with the trade date
one_month = trade_date + calmonths(1);
%[minm, min_idx] = min(abs(rates.DATETIME - one_month))

spot = rates.SPOT((rates.DATETIME >= trade_date) & (rates.DATETIME <= one_month));
sum = 0;

for i = 1:(length(spot)-1)
    ln = log(rates.SPOT(i) / rates.SPOT(i+1))^2;    
    sum = sum + ln;
end

sigma_r = sum / height(rates);
end

function [ki] = K_Var(opt, rates)
%filter data to today and get kvar

%opt = opt(opt.DATETIME == trade_date);
%rates = rates(rates.DATETIME == trade_date);

ki = swap_calc_onetenor(opt, rates);
end

function K_var =  swap_calc_onetenor(options, rates)
    %Usage swap_calc(
    %options = import_options(opt_file);
    %rates = import_rates(rate_file);
    %options.EXPIRY = round(options.EXPIRY, 6);
    %rates.EXPIRY = round(rates.EXPIRY, 6);
    
    S_0 = rates.SPOT;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    tenor = rates.EXPIRY;
    %sample = options((options.EXPIRY == tenor), :);
    sample = options;
    R = rates.RATE - rates.DIV;
    % r = rates.RATE(i);

    %sample(end,:) = []; %delete last row since it seems to be a troublemaker

    sample = sortrows(sample, 2); %sort data by strike column, ascending

    strike = sample.STRIKE;
    call = sample.CALL;
    put = sample.PUT;

    call_inv_weighted = call./(strike.^2);
    put_inv_weighted = put./(strike.^2);


    diff = abs(call - put);
    index_of_smallest_diff = find(diff == min(diff));
    S_star = strike(index_of_smallest_diff);

    spline_of_call = spline(strike, call_inv_weighted);
    spline_of_call.coefs(end,:) = [0 0 0 0];

    spline_of_put = spline(strike, put_inv_weighted);
    spline_of_put.coefs(1,:) = [0 0 0 0];

    K_var = (2/tenor)*(R*tenor-((S_0/S_star)*exp(R*tenor)-1) - log(S_star/S_0) ...
            + exp(R*tenor)*integral(@(t)ppval(spline_of_put,t), 0, S_star)...
            + exp(R*tenor)*integral(@(t)ppval(spline_of_call,t), S_star, inf));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end