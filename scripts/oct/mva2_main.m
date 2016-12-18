addpath ("./scripts/oct/")%nS = 5 % number of servers%nR = 1 % replication%nT = 32 % number of threads%nC = 180 % number of clients%pW = 5 / 100 % proportion of writes%%tNW_g = 2.826752%tLB_g = 0.003863378%tNW_s = 2.858229%tLB_s = 0.003403551%tWW = 2%tRW = 1%tMC = 1%%result_path = "results/analysis/part3_network/mva/testing/model2test.mat"arg_list = argv ();num_args_required = 14;if(length(arg_list) != num_args_required)    printf("Check usage: %d arguments given, %d required.\n", length(arg_list), num_args_required);    return;endifoffset = 1;result_path = arg_list{1}nS = str2num(arg_list{1 + offset}) % number of serversnR = str2num(arg_list{2 + offset}) % number of threadsnT = str2num(arg_list{3 + offset}) % number of threadsnC = str2num(arg_list{4 + offset}) % number of clientspW = str2num(arg_list{5 + offset}) / 100 % proportion of writestNW_g = str2num(arg_list{6 + offset})tNW_s = str2num(arg_list{7 + offset})tLB_g = str2num(arg_list{8 + offset})tLB_s = str2num(arg_list{9 + offset})tWW = str2num(arg_list{10 + offset})tRW = str2num(arg_list{11 + offset})tMC = str2num(arg_list{12 + offset})tWWR = str2num(arg_list{13 + offset})[U, R, Q, X] = mva_model2(result_path, nS, nR, nT, nC, pW, tNW_g, tNW_s, tLB_g, tLB_s, tWW, tRW, tMC, tWWR);