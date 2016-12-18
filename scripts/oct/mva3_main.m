addpath ("./scripts/oct/")%nS = 5 % number of servers%nT = 32 % number of threads%nC = 180 % number of clients%pW = 5 / 100 % proportion of writes%%tNW_g = 2.826752%tLB_g = 0.003863378%tMC_g = 3.048588%tNW_s = 2.858229%tLB_s = 0.003403551%tMC_s = 3.122988arg_list = argv ();num_args_required = 11;if(length(arg_list) != num_args_required)    printf("Check usage: %d arguments given, %d required.\n", length(arg_list), num_args_required);    return;endifoffset = 1;result_path = arg_list{1}nS = str2num(arg_list{1 + offset}) % number of serversnT = str2num(arg_list{2 + offset}) % number of threadsnC = str2num(arg_list{3 + offset}) % number of clientspW = str2num(arg_list{4 + offset}) / 100 % proportion of writestNW_g = str2num(arg_list{5 + offset})tNW_s = str2num(arg_list{6 + offset})tLB_g = str2num(arg_list{7 + offset})tLB_s = str2num(arg_list{8 + offset})tWW = str2num(arg_list{9 + offset})tRW = str2num(arg_list{10 + offset})[U, R, Q, X] = mva_model1_multiclass(result_path, nS, nT, nC, pW, tNW_g, tNW_s, tLB_g, tLB_s, tWW, tRW);