import re

data = """
Godot Engine v4.6.2.stable.mono.official.71f334935 - https://godotengine.org
OpenGL API 3.3.0 - Build 32.0.101.7026 - Compatibility - Using Device: Intel - Intel(R) Iris(R) Xe Graphics

Min: -9 Max: 18
Bike: @PathFollow3D@31 Finish time: 13357.4766685543 Remaining_Timer: 7286.72666855457  Watts: 391
total_time: 13357.4766685543 total threashold: 6070.75 Total_Speed: 309875.456762347 Total_processcounter: 25041 Threahold_Counter: 24283
Bike: @PathFollow3D@42 Finish time: 13357.4766685543 Remaining_Timer: 7286.72666855457  Watts: 391
total_time: 13357.4766685543 total threashold: 6070.75 Total_Speed: 309945.829185452 Total_processcounter: 25041 Threahold_Counter: 24283
Bike: @PathFollow3D@99 Finish time: 13357.4766685543 Remaining_Timer: 7286.72666855457  Watts: 391
total_time: 13357.4766685543 total threashold: 6070.75 Total_Speed: 309827.227151312 Total_processcounter: 25041 Threahold_Counter: 24283
Bike: @PathFollow3D@118 Finish time: 13357.4766685543 Remaining_Timer: 7286.72666855457  Watts: 391
total_time: 13357.4766685543 total threashold: 6070.75 Total_Speed: 309851.230578996 Total_processcounter: 25041 Threahold_Counter: 24283
Bike: @PathFollow3D@123 Finish time: 13357.4766685543 Remaining_Timer: 7286.72666855457  Watts: 391
total_time: 13357.4766685543 total threashold: 6070.75 Total_Speed: 309588.194949648 Total_processcounter: 25041 Threahold_Counter: 24283
Bike: @PathFollow3D@126 Finish time: 13357.4766685543 Remaining_Timer: 7286.72666855457  Watts: 391
total_time: 13357.4766685543 total threashold: 6070.75 Total_Speed: 309950.336163795 Total_processcounter: 25041 Threahold_Counter: 24283
Bike: @PathFollow3D@132 Finish time: 13357.4766685543 Remaining_Timer: 7286.72666855457  Watts: 391
total_time: 13357.4766685543 total threashold: 6070.75 Total_Speed: 309862.324431154 Total_processcounter: 25041 Threahold_Counter: 24283
Bike: @PathFollow3D@40 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309797.816336113 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@75 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309662.145798454 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@98 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309603.828122804 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@111 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309659.806453566 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@136 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309818.391664586 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@140 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309898.243528321 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@153 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309624.134992066 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@156 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309910.979722038 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@158 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309862.9896533 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@160 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309877.363532576 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@164 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309916.122653811 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@177 Finish time: 13357.8544463321 Remaining_Timer: 7286.85444633235  Watts: 391
total_time: 13357.8544463321 total threashold: 6071.0 Total_Speed: 309888.071694657 Total_processcounter: 25042 Threahold_Counter: 24284
Bike: @PathFollow3D@46 Finish time: 13358.235398713 Remaining_Timer: 7286.9853987133  Watts: 391
total_time: 13358.235398713 total threashold: 6071.25 Total_Speed: 309715.008371066 Total_processcounter: 25043 Threahold_Counter: 24285
Bike: @PathFollow3D@125 Finish time: 13358.235398713 Remaining_Timer: 7286.9853987133  Watts: 391
total_time: 13358.235398713 total threashold: 6071.25 Total_Speed: 309634.954578046 Total_processcounter: 25043 Threahold_Counter: 24285
Bike: @PathFollow3D@133 Finish time: 13358.235398713 Remaining_Timer: 7286.9853987133  Watts: 391
total_time: 13358.235398713 total threashold: 6071.25 Total_Speed: 309538.092904427 Total_processcounter: 25043 Threahold_Counter: 24285
Bike: @PathFollow3D@135 Finish time: 13358.235398713 Remaining_Timer: 7286.9853987133  Watts: 391
total_time: 13358.235398713 total threashold: 6071.25 Total_Speed: 309918.408256734 Total_processcounter: 25043 Threahold_Counter: 24285
Bike: @PathFollow3D@152 Finish time: 13358.235398713 Remaining_Timer: 7286.9853987133  Watts: 391
total_time: 13358.235398713 total threashold: 6071.25 Total_Speed: 309775.433392066 Total_processcounter: 25043 Threahold_Counter: 24285
Bike: @PathFollow3D@174 Finish time: 13358.235398713 Remaining_Timer: 7286.9853987133  Watts: 391
total_time: 13358.235398713 total threashold: 6071.25 Total_Speed: 309883.730931371 Total_processcounter: 25043 Threahold_Counter: 24285
Bike: @PathFollow3D@176 Finish time: 13358.235398713 Remaining_Timer: 7286.9853987133  Watts: 391
total_time: 13358.235398713 total threashold: 6071.25 Total_Speed: 309788.061865638 Total_processcounter: 25043 Threahold_Counter: 24285
Bike: @PathFollow3D@12 Finish time: 13358.616351094 Remaining_Timer: 7287.11635109425  Watts: 391
total_time: 13358.616351094 total threashold: 6071.5 Total_Speed: 309771.29290926 Total_processcounter: 25044 Threahold_Counter: 24286
Bike: @PathFollow3D@14 Finish time: 13359.3637209987 Remaining_Timer: 7287.36372099902  Watts: 391
total_time: 13359.3637209987 total threashold: 6072.0 Total_Speed: 309727.006352662 Total_processcounter: 25046 Threahold_Counter: 24288
Bike: @PathFollow3D@70 Finish time: 13359.3637209987 Remaining_Timer: 7287.36372099902  Watts: 391
total_time: 13359.3637209987 total threashold: 6072.0 Total_Speed: 309697.841651647 Total_processcounter: 25046 Threahold_Counter: 24288
Bike: @PathFollow3D@108 Finish time: 13359.3637209987 Remaining_Timer: 7287.36372099902  Watts: 391
total_time: 13359.3637209987 total threashold: 6072.0 Total_Speed: 309876.187028155 Total_processcounter: 25046 Threahold_Counter: 24288
Bike: @PathFollow3D@120 Finish time: 13359.3637209987 Remaining_Timer: 7287.36372099902  Watts: 391
total_time: 13359.3637209987 total threashold: 6072.0 Total_Speed: 309983.611691601 Total_processcounter: 25046 Threahold_Counter: 24288
Bike: @PathFollow3D@137 Finish time: 13359.8401849987 Remaining_Timer: 7287.34018499902  Watts: 391
total_time: 13359.8401849987 total threashold: 6072.5 Total_Speed: 309776.811971422 Total_processcounter: 25048 Threahold_Counter: 24290
Bike: @PathFollow3D@21 Finish time: 13362.2391556654 Remaining_Timer: 7287.48915566568  Watts: 382
total_time: 13362.2391556654 total threashold: 6074.75 Total_Speed: 309539.461591617 Total_processcounter: 25057 Threahold_Counter: 24299
Bike: @PathFollow3D@4 Finish time: 13375.5705956654 Remaining_Timer: 7288.32059566567  Watts: 382
total_time: 13375.5705956654 total threashold: 6087.25 Total_Speed: 309940.148955645 Total_processcounter: 25107 Threahold_Counter: 24349
Bike: @PathFollow3D@55 Finish time: 13375.8372623321 Remaining_Timer: 7288.33726233234  Watts: 382
total_time: 13375.8372623321 total threashold: 6087.5 Total_Speed: 309907.436319331 Total_processcounter: 25108 Threahold_Counter: 24350
Bike: @PathFollow3D@71 Finish time: 13375.8372623321 Remaining_Timer: 7288.33726233234  Watts: 382
total_time: 13375.8372623321 total threashold: 6087.5 Total_Speed: 310088.205351194 Total_processcounter: 25108 Threahold_Counter: 24350
Bike: @PathFollow3D@83 Finish time: 13376.1039289987 Remaining_Timer: 7288.353928999  Watts: 382
total_time: 13376.1039289987 total threashold: 6087.75 Total_Speed: 310087.015786518 Total_processcounter: 25109 Threahold_Counter: 24351
Bike: @PathFollow3D@86 Finish time: 13376.1039289987 Remaining_Timer: 7288.353928999  Watts: 382
total_time: 13376.1039289987 total threashold: 6087.75 Total_Speed: 310011.713370917 Total_processcounter: 25109 Threahold_Counter: 24351
Bike: @PathFollow3D@163 Finish time: 13376.1039289987 Remaining_Timer: 7288.353928999  Watts: 382
total_time: 13376.1039289987 total threashold: 6087.75 Total_Speed: 310123.570317614 Total_processcounter: 25109 Threahold_Counter: 24351
Bike: @PathFollow3D@19 Finish time: 13376.3705956654 Remaining_Timer: 7288.37059566567  Watts: 382
total_time: 13376.3705956654 total threashold: 6088.0 Total_Speed: 309941.865224289 Total_processcounter: 25110 Threahold_Counter: 24352
Bike: @PathFollow3D@44 Finish time: 13376.3705956654 Remaining_Timer: 7288.37059566567  Watts: 382
total_time: 13376.3705956654 total threashold: 6088.0 Total_Speed: 309815.466920811 Total_processcounter: 25110 Threahold_Counter: 24352
Bike: @PathFollow3D@47 Finish time: 13376.3705956654 Remaining_Timer: 7288.37059566567  Watts: 382
total_time: 13376.3705956654 total threashold: 6088.0 Total_Speed: 310066.555459524 Total_processcounter: 25110 Threahold_Counter: 24352
Bike: @PathFollow3D@87 Finish time: 13376.3705956654 Remaining_Timer: 7288.37059566567  Watts: 382
total_time: 13376.3705956654 total threashold: 6088.0 Total_Speed: 309999.61186196 Total_processcounter: 25110 Threahold_Counter: 24352
Bike: @PathFollow3D@105 Finish time: 13376.3705956654 Remaining_Timer: 7288.37059566567  Watts: 382
total_time: 13376.3705956654 total threashold: 6088.0 Total_Speed: 309994.559968348 Total_processcounter: 25110 Threahold_Counter: 24352
Bike: @PathFollow3D@119 Finish time: 13376.3705956654 Remaining_Timer: 7288.37059566567  Watts: 382
total_time: 13376.3705956654 total threashold: 6088.0 Total_Speed: 309963.368371104 Total_processcounter: 25110 Threahold_Counter: 24352
Bike: @PathFollow3D@127 Finish time: 13376.3705956654 Remaining_Timer: 7288.37059566567  Watts: 382
total_time: 13376.3705956654 total threashold: 6088.0 Total_Speed: 309982.129471612 Total_processcounter: 25110 Threahold_Counter: 24352
Bike: @PathFollow3D@5 Finish time: 13376.6372623321 Remaining_Timer: 7288.38726233234  Watts: 382
total_time: 13376.6372623321 total threashold: 6088.25 Total_Speed: 310022.475371757 Total_processcounter: 25111 Threahold_Counter: 24353
Bike: @PathFollow3D@61 Finish time: 13376.6372623321 Remaining_Timer: 7288.38726233234  Watts: 382
total_time: 13376.6372623321 total threashold: 6088.25 Total_Speed: 309824.993768979 Total_processcounter: 25111 Threahold_Counter: 24353
Bike: @PathFollow3D@77 Finish time: 13376.6372623321 Remaining_Timer: 7288.38726233234  Watts: 382
total_time: 13376.6372623321 total threashold: 6088.25 Total_Speed: 310033.766950332 Total_processcounter: 25111 Threahold_Counter: 24353
Bike: @PathFollow3D@25 Finish time: 13376.9039289987 Remaining_Timer: 7288.403928999  Watts: 382
total_time: 13376.9039289987 total threashold: 6088.5 Total_Speed: 309934.995359232 Total_processcounter: 25112 Threahold_Counter: 24354
Bike: @PathFollow3D@68 Finish time: 13376.9039289987 Remaining_Timer: 7288.403928999  Watts: 382
total_time: 13376.9039289987 total threashold: 6088.5 Total_Speed: 309904.285538769 Total_processcounter: 25112 Threahold_Counter: 24354
Bike: @PathFollow3D@54 Finish time: 13377.1705956654 Remaining_Timer: 7288.42059566567  Watts: 382
total_time: 13377.1705956654 total threashold: 6088.75 Total_Speed: 309964.080460023 Total_processcounter: 25113 Threahold_Counter: 24355
Bike: @PathFollow3D@32 Finish time: 13377.4372623321 Remaining_Timer: 7288.43726233234  Watts: 382
total_time: 13377.4372623321 total threashold: 6089.0 Total_Speed: 309890.503796277 Total_processcounter: 25114 Threahold_Counter: 24356
Bike: @PathFollow3D@51 Finish time: 13377.4372623321 Remaining_Timer: 7288.43726233234  Watts: 382
total_time: 13377.4372623321 total threashold: 6089.0 Total_Speed: 310040.560236834 Total_processcounter: 25114 Threahold_Counter: 24356
Bike: @PathFollow3D@110 Finish time: 13377.4372623321 Remaining_Timer: 7288.43726233234  Watts: 382
total_time: 13377.4372623321 total threashold: 6089.0 Total_Speed: 309951.919681317 Total_processcounter: 25114 Threahold_Counter: 24356
Bike: @PathFollow3D@8 Finish time: 13377.7039289987 Remaining_Timer: 7288.453928999  Watts: 382
total_time: 13377.7039289987 total threashold: 6089.25 Total_Speed: 310043.740783396 Total_processcounter: 25115 Threahold_Counter: 24357
Bike: @PathFollow3D@28 Finish time: 13377.7039289987 Remaining_Timer: 7288.453928999  Watts: 382
total_time: 13377.7039289987 total threashold: 6089.25 Total_Speed: 310104.200733961 Total_processcounter: 25115 Threahold_Counter: 24357
Bike: @PathFollow3D@49 Finish time: 13377.7039289987 Remaining_Timer: 7288.453928999  Watts: 382
total_time: 13377.7039289987 total threashold: 6089.25 Total_Speed: 309979.759406607 Total_processcounter: 25115 Threahold_Counter: 24357
Bike: @PathFollow3D@62 Finish time: 13377.7039289987 Remaining_Timer: 7288.453928999  Watts: 373
total_time: 13377.7039289987 total threashold: 6089.25 Total_Speed: 309980.100223087 Total_processcounter: 25115 Threahold_Counter: 24357
Bike: @PathFollow3D@103 Finish time: 13377.7039289987 Remaining_Timer: 7288.453928999  Watts: 382
total_time: 13377.7039289987 total threashold: 6089.25 Total_Speed: 309786.220480621 Total_processcounter: 25115 Threahold_Counter: 24357
Bike: @PathFollow3D@22 Finish time: 13377.9705956654 Remaining_Timer: 7288.47059566567  Watts: 382
total_time: 13377.9705956654 total threashold: 6089.5 Total_Speed: 310009.700470277 Total_processcounter: 25116 Threahold_Counter: 24358
Bike: @PathFollow3D@23 Finish time: 13378.2372623321 Remaining_Timer: 7288.48726233234  Watts: 382
total_time: 13378.2372623321 total threashold: 6089.75 Total_Speed: 309899.045612666 Total_processcounter: 25117 Threahold_Counter: 24359
Bike: @PathFollow3D@148 Finish time: 13378.5039289987 Remaining_Timer: 7288.503928999  Watts: 382
total_time: 13378.5039289987 total threashold: 6090.0 Total_Speed: 310116.317579018 Total_processcounter: 25118 Threahold_Counter: 24360
Bike: @PathFollow3D@29 Finish time: 13378.7705956654 Remaining_Timer: 7288.52059566567  Watts: 382
total_time: 13378.7705956654 total threashold: 6090.25 Total_Speed: 310132.142168766 Total_processcounter: 25119 Threahold_Counter: 24361
Bike: @PathFollow3D@106 Finish time: 13442.4956089987 Remaining_Timer: 7292.49560899894  Watts: 391
total_time: 13442.4956089987 total threashold: 6150.0 Total_Speed: 311789.373555969 Total_processcounter: 25358 Threahold_Counter: 24600
Bike: @PathFollow3D@134 Finish time: 13442.7622756653 Remaining_Timer: 7292.51227566561  Watts: 391
total_time: 13442.7622756653 total threashold: 6150.25 Total_Speed: 311303.628799919 Total_processcounter: 25359 Threahold_Counter: 24601
Bike: @PathFollow3D@144 Finish time: 13442.7622756653 Remaining_Timer: 7292.51227566561  Watts: 391
total_time: 13442.7622756653 total threashold: 6150.25 Total_Speed: 311425.793420938 Total_processcounter: 25359 Threahold_Counter: 24601
Bike: @PathFollow3D@96 Finish time: 13443.028942332 Remaining_Timer: 7292.52894233228  Watts: 391
total_time: 13443.028942332 total threashold: 6150.5 Total_Speed: 311581.186318731 Total_processcounter: 25360 Threahold_Counter: 24602
Bike: @PathFollow3D@100 Finish time: 13443.028942332 Remaining_Timer: 7292.52894233228  Watts: 391
total_time: 13443.028942332 total threashold: 6150.5 Total_Speed: 311484.320675606 Total_processcounter: 25360 Threahold_Counter: 24602
Bike: @PathFollow3D@145 Finish time: 13443.2956089987 Remaining_Timer: 7292.54560899894  Watts: 391
total_time: 13443.2956089987 total threashold: 6150.75 Total_Speed: 311385.287120223 Total_processcounter: 25361 Threahold_Counter: 24603
Bike: @PathFollow3D@80 Finish time: 13459.2936569987 Remaining_Timer: 7293.54365699893  Watts: 382
total_time: 13459.2936569987 total threashold: 6165.75 Total_Speed: 311416.155380208 Total_processcounter: 25421 Threahold_Counter: 24663
Bike: @PathFollow3D@78 Finish time: 13459.5603236653 Remaining_Timer: 7293.5603236656  Watts: 382
total_time: 13459.5603236653 total threashold: 6166.0 Total_Speed: 311521.981377965 Total_processcounter: 25422 Threahold_Counter: 24664
Bike: @PathFollow3D@92 Finish time: 13459.5603236653 Remaining_Timer: 7293.5603236656  Watts: 382
total_time: 13459.5603236653 total threashold: 6166.0 Total_Speed: 311338.932215083 Total_processcounter: 25422 Threahold_Counter: 24664
Bike: @PathFollow3D@175 Finish time: 13459.5603236653 Remaining_Timer: 7293.5603236656  Watts: 382
total_time: 13459.5603236653 total threashold: 6166.0 Total_Speed: 311270.69011026 Total_processcounter: 25422 Threahold_Counter: 24664
Bike: @PathFollow3D@168 Finish time: 13459.826990332 Remaining_Timer: 7293.57699033226  Watts: 382
total_time: 13459.826990332 total threashold: 6166.25 Total_Speed: 311349.963444198 Total_processcounter: 25423 Threahold_Counter: 24665
Bike: @PathFollow3D@48 Finish time: 13460.0936569987 Remaining_Timer: 7293.59365699893  Watts: 382
total_time: 13460.0936569987 total threashold: 6166.5 Total_Speed: 311540.389319829 Total_processcounter: 25424 Threahold_Counter: 24666
Bike: @PathFollow3D@142 Finish time: 13460.0936569987 Remaining_Timer: 7293.59365699893  Watts: 382
total_time: 13460.0936569987 total threashold: 6166.5 Total_Speed: 311301.574764908 Total_processcounter: 25424 Threahold_Counter: 24666
Bike: @PathFollow3D@169 Finish time: 13460.0936569987 Remaining_Timer: 7293.59365699893  Watts: 382
total_time: 13460.0936569987 total threashold: 6166.5 Total_Speed: 311524.31381977 Total_processcounter: 25424 Threahold_Counter: 24666
Bike: @PathFollow3D@34 Finish time: 13460.3603236653 Remaining_Timer: 7293.6103236656  Watts: 382
total_time: 13460.3603236653 total threashold: 6166.75 Total_Speed: 311567.497570084 Total_processcounter: 25425 Threahold_Counter: 24667
Bike: @PathFollow3D@56 Finish time: 13460.3603236653 Remaining_Timer: 7293.6103236656  Watts: 382
total_time: 13460.3603236653 total threashold: 6166.75 Total_Speed: 311920.390170999 Total_processcounter: 25425 Threahold_Counter: 24667
Bike: @PathFollow3D@181 Finish time: 13460.3603236653 Remaining_Timer: 7293.6103236656  Watts: 382
total_time: 13460.3603236653 total threashold: 6166.75 Total_Speed: 311389.893766418 Total_processcounter: 25425 Threahold_Counter: 24667
Bike: @PathFollow3D@60 Finish time: 13460.626990332 Remaining_Timer: 7293.62699033226  Watts: 373
total_time: 13460.626990332 total threashold: 6167.0 Total_Speed: 311549.932533959 Total_processcounter: 25426 Threahold_Counter: 24668
Bike: @PathFollow3D@173 Finish time: 13460.626990332 Remaining_Timer: 7293.62699033226  Watts: 373
total_time: 13460.626990332 total threashold: 6167.0 Total_Speed: 311623.666535153 Total_processcounter: 25426 Threahold_Counter: 24668
Bike: @PathFollow3D@57 Finish time: 13460.8936569987 Remaining_Timer: 7293.64365699893  Watts: 373
total_time: 13460.8936569987 total threashold: 6167.25 Total_Speed: 311574.298486559 Total_processcounter: 25427 Threahold_Counter: 24669
Bike: @PathFollow3D@112 Finish time: 13460.8936569987 Remaining_Timer: 7293.64365699893  Watts: 382
total_time: 13460.8936569987 total threashold: 6167.25 Total_Speed: 311212.951141891 Total_processcounter: 25427 Threahold_Counter: 24669
Bike: @PathFollow3D@138 Finish time: 13460.8936569987 Remaining_Timer: 7293.64365699893  Watts: 373
total_time: 13460.8936569987 total threashold: 6167.25 Total_Speed: 311217.749994793 Total_processcounter: 25427 Threahold_Counter: 24669
Bike: @PathFollow3D@36 Finish time: 13461.1583929987 Remaining_Timer: 7293.65839299893  Watts: 373
total_time: 13461.1583929987 total threashold: 6167.5 Total_Speed: 311627.024642909 Total_processcounter: 25428 Threahold_Counter: 24670
Bike: @PathFollow3D@43 Finish time: 13461.4250596653 Remaining_Timer: 7293.6750596656  Watts: 373
total_time: 13461.4250596653 total threashold: 6167.75 Total_Speed: 311562.251615206 Total_processcounter: 25429 Threahold_Counter: 24671
Bike: @PathFollow3D@59 Finish time: 13461.4250596653 Remaining_Timer: 7293.6750596656  Watts: 373
total_time: 13461.4250596653 total threashold: 6167.75 Total_Speed: 311823.062922989 Total_processcounter: 25429 Threahold_Counter: 24671
Bike: @PathFollow3D@115 Finish time: 13461.4250596653 Remaining_Timer: 7293.6750596656  Watts: 373
total_time: 13461.4250596653 total threashold: 6167.75 Total_Speed: 311263.138461134 Total_processcounter: 25429 Threahold_Counter: 24671
Bike: @PathFollow3D@172 Finish time: 13461.4250596653 Remaining_Timer: 7293.6750596656  Watts: 373
total_time: 13461.4250596653 total threashold: 6167.75 Total_Speed: 311820.596135509 Total_processcounter: 25429 Threahold_Counter: 24671
Bike: @PathFollow3D@143 Finish time: 13461.691726332 Remaining_Timer: 7293.69172633226  Watts: 373
total_time: 13461.691726332 total threashold: 6168.0 Total_Speed: 311084.967527543 Total_processcounter: 25430 Threahold_Counter: 24672
Bike: @PathFollow3D@171 Finish time: 13461.691726332 Remaining_Timer: 7293.69172633226  Watts: 373
total_time: 13461.691726332 total threashold: 6168.0 Total_Speed: 311439.181744525 Total_processcounter: 25430 Threahold_Counter: 24672
Bike: @PathFollow3D@67 Finish time: 13461.9583609987 Remaining_Timer: 7293.70836099893  Watts: 373
total_time: 13461.9583609987 total threashold: 6168.25 Total_Speed: 311855.090171806 Total_processcounter: 25431 Threahold_Counter: 24673
Bike: @PathFollow3D@69 Finish time: 13461.9583609987 Remaining_Timer: 7293.70836099893  Watts: 373
total_time: 13461.9583609987 total threashold: 6168.25 Total_Speed: 311267.226109233 Total_processcounter: 25431 Threahold_Counter: 24673
Bike: @PathFollow3D@73 Finish time: 13461.9583609987 Remaining_Timer: 7293.70836099893  Watts: 373
total_time: 13461.9583609987 total threashold: 6168.25 Total_Speed: 311267.651778887 Total_processcounter: 25431 Threahold_Counter: 24673
Bike: @PathFollow3D@139 Finish time: 13461.9583609987 Remaining_Timer: 7293.70836099893  Watts: 373
total_time: 13461.9583609987 total threashold: 6168.25 Total_Speed: 311493.322648394 Total_processcounter: 25431 Threahold_Counter: 24673
Bike: @PathFollow3D@170 Finish time: 13461.9583609987 Remaining_Timer: 7293.70836099893  Watts: 373
total_time: 13461.9583609987 total threashold: 6168.25 Total_Speed: 311260.265644084 Total_processcounter: 25431 Threahold_Counter: 24673
Bike: @PathFollow3D@182 Finish time: 13461.9583609987 Remaining_Timer: 7293.70836099893  Watts: 373
total_time: 13461.9583609987 total threashold: 6168.25 Total_Speed: 311356.283978029 Total_processcounter: 25431 Threahold_Counter: 24673
Bike: @PathFollow3D@89 Finish time: 13462.2250276653 Remaining_Timer: 7293.7250276656  Watts: 373
total_time: 13462.2250276653 total threashold: 6168.5 Total_Speed: 311113.732925117 Total_processcounter: 25432 Threahold_Counter: 24674
Bike: @PathFollow3D@128 Finish time: 13462.2250276653 Remaining_Timer: 7293.7250276656  Watts: 373
total_time: 13462.2250276653 total threashold: 6168.5 Total_Speed: 311517.113348579 Total_processcounter: 25432 Threahold_Counter: 24674
Bike: @PathFollow3D@157 Finish time: 13462.491694332 Remaining_Timer: 7293.74169433226  Watts: 373
total_time: 13462.491694332 total threashold: 6168.75 Total_Speed: 311387.849228826 Total_processcounter: 25433 Threahold_Counter: 24675
Bike: @PathFollow3D@64 Finish time: 13541.4143343319 Remaining_Timer: 7298.66433433219  Watts: 373
total_time: 13541.4143343319 total threashold: 6242.75 Total_Speed: 312767.270977793 Total_processcounter: 25729 Threahold_Counter: 24971
Bike: @PathFollow3D@58 Finish time: 13560.0791929986 Remaining_Timer: 7299.82919299884  Watts: 382
total_time: 13560.0791929986 total threashold: 6260.25 Total_Speed: 312862.331509491 Total_processcounter: 25799 Threahold_Counter: 25041
Bike: @PathFollow3D@146 Finish time: 13561.6791929986 Remaining_Timer: 7299.92919299884  Watts: 373
total_time: 13561.6791929986 total threashold: 6261.75 Total_Speed: 313363.779135146 Total_processcounter: 25805 Threahold_Counter: 25047
Bike: @PathFollow3D@154 Finish time: 13561.6791929986 Remaining_Timer: 7299.92919299884  Watts: 373
total_time: 13561.6791929986 total threashold: 6261.75 Total_Speed: 313287.164846601 Total_processcounter: 25805 Threahold_Counter: 25047
Bike: @PathFollow3D@63 Finish time: 13561.9458596652 Remaining_Timer: 7299.94585966551  Watts: 373
total_time: 13561.9458596652 total threashold: 6262.0 Total_Speed: 313151.276855381 Total_processcounter: 25806 Threahold_Counter: 25048
Bike: @PathFollow3D@65 Finish time: 13561.9458596652 Remaining_Timer: 7299.94585966551  Watts: 373
total_time: 13561.9458596652 total threashold: 6262.0 Total_Speed: 312987.084011776 Total_processcounter: 25806 Threahold_Counter: 25048
Bike: @PathFollow3D@76 Finish time: 13561.9458596652 Remaining_Timer: 7299.94585966551  Watts: 373
total_time: 13561.9458596652 total threashold: 6262.0 Total_Speed: 312884.053006243 Total_processcounter: 25806 Threahold_Counter: 25048
Bike: @PathFollow3D@82 Finish time: 13561.9458596652 Remaining_Timer: 7299.94585966551  Watts: 373
total_time: 13561.9458596652 total threashold: 6262.0 Total_Speed: 313225.44627714 Total_processcounter: 25806 Threahold_Counter: 25048
Bike: @PathFollow3D@129 Finish time: 13561.9458596652 Remaining_Timer: 7299.94585966551  Watts: 373
total_time: 13561.9458596652 total threashold: 6262.0 Total_Speed: 313174.610563543 Total_processcounter: 25806 Threahold_Counter: 25048
Bike: @PathFollow3D@149 Finish time: 13561.9458596652 Remaining_Timer: 7299.94585966551  Watts: 373
total_time: 13561.9458596652 total threashold: 6262.0 Total_Speed: 313177.659570684 Total_processcounter: 25806 Threahold_Counter: 25048
Bike: @PathFollow3D@159 Finish time: 13561.9458596652 Remaining_Timer: 7299.94585966551  Watts: 373
total_time: 13561.9458596652 total threashold: 6262.0 Total_Speed: 313163.310729526 Total_processcounter: 25806 Threahold_Counter: 25048
Bike: @PathFollow3D@131 Finish time: 13567.8123503319 Remaining_Timer: 7300.31235033217  Watts: 373
total_time: 13567.8123503319 total threashold: 6267.5 Total_Speed: 312916.859231097 Total_processcounter: 25828 Threahold_Counter: 25070
Bike: @PathFollow3D@53 Finish time: 13568.0790169986 Remaining_Timer: 7300.32901699884  Watts: 373
total_time: 13568.0790169986 total threashold: 6267.75 Total_Speed: 312721.705096707 Total_processcounter: 25829 Threahold_Counter: 25071
Bike: @PathFollow3D@79 Finish time: 13568.0790169986 Remaining_Timer: 7300.32901699884  Watts: 373
total_time: 13568.0790169986 total threashold: 6267.75 Total_Speed: 313338.586500463 Total_processcounter: 25829 Threahold_Counter: 25071
Bike: @PathFollow3D@97 Finish time: 13568.3456836652 Remaining_Timer: 7300.3456836655  Watts: 373
total_time: 13568.3456836652 total threashold: 6268.0 Total_Speed: 313267.012399439 Total_processcounter: 25830 Threahold_Counter: 25072
Bike: @PathFollow3D@150 Finish time: 13575.0108036652 Remaining_Timer: 7300.7608036655  Watts: 373
total_time: 13575.0108036652 total threashold: 6274.25 Total_Speed: 313403.38586325 Total_processcounter: 25855 Threahold_Counter: 25097
Bike: @PathFollow3D@165 Finish time: 13575.0108036652 Remaining_Timer: 7300.7608036655  Watts: 373
total_time: 13575.0108036652 total threashold: 6274.25 Total_Speed: 313168.84272945 Total_processcounter: 25855 Threahold_Counter: 25097
Bike: @PathFollow3D@121 Finish time: 13576.6108036652 Remaining_Timer: 7300.8608036655  Watts: 373
total_time: 13576.6108036652 total threashold: 6275.75 Total_Speed: 313240.922936131 Total_processcounter: 25861 Threahold_Counter: 25103
Bike: @PathFollow3D@167 Finish time: 13577.9441369986 Remaining_Timer: 7300.94413699883  Watts: 373
total_time: 13577.9441369986 total threashold: 6277.0 Total_Speed: 313387.892516044 Total_processcounter: 25866 Threahold_Counter: 25108
Bike: @PathFollow3D@117 Finish time: 13579.8108036652 Remaining_Timer: 7301.06080366549  Watts: 373
total_time: 13579.8108036652 total threashold: 6278.75 Total_Speed: 313192.043343665 Total_processcounter: 25873 Threahold_Counter: 25115
Bike: @PathFollow3D@13 Finish time: 13582.2108036652 Remaining_Timer: 7301.21080366549  Watts: 373
total_time: 13582.2108036652 total threashold: 6281.0 Total_Speed: 313564.310892608 Total_processcounter: 25882 Threahold_Counter: 25124
Bike: @PathFollow3D@102 Finish time: 13660.8771129985 Remaining_Timer: 7306.12711299875  Watts: 373
total_time: 13660.8771129985 total threashold: 6354.75 Total_Speed: 314861.481285909 Total_processcounter: 26177 Threahold_Counter: 25419
Bike: @PathFollow3D@74 Finish time: 13662.4770489985 Remaining_Timer: 7306.22704899875  Watts: 364
total_time: 13662.4770489985 total threashold: 6356.25 Total_Speed: 314577.028876367 Total_processcounter: 26183 Threahold_Counter: 25425
Bike: @PathFollow3D@162 Finish time: 13662.4770489985 Remaining_Timer: 7306.22704899875  Watts: 364
total_time: 13662.4770489985 total threashold: 6356.25 Total_Speed: 314677.670100365 Total_processcounter: 26183 Threahold_Counter: 25425
Bike: @PathFollow3D@166 Finish time: 13662.4770489985 Remaining_Timer: 7306.22704899875  Watts: 364
total_time: 13662.4770489985 total threashold: 6356.25 Total_Speed: 314688.309990302 Total_processcounter: 26183 Threahold_Counter: 25425
Bike: @PathFollow3D@39 Finish time: 13662.7437049985 Remaining_Timer: 7306.24370499875  Watts: 364
total_time: 13662.7437049985 total threashold: 6356.5 Total_Speed: 314539.787613697 Total_processcounter: 26184 Threahold_Counter: 25426
Bike: @PathFollow3D@180 Finish time: 13662.7437049985 Remaining_Timer: 7306.24370499875  Watts: 364
total_time: 13662.7437049985 total threashold: 6356.5 Total_Speed: 314672.942378995 Total_processcounter: 26184 Threahold_Counter: 25426
Bike: @PathFollow3D@26 Finish time: 13677.6764409985 Remaining_Timer: 7307.17644099874  Watts: 364
total_time: 13677.6764409985 total threashold: 6370.5 Total_Speed: 314729.486352106 Total_processcounter: 26240 Threahold_Counter: 25482
Bike: @PathFollow3D@18 Finish time: 13693.4091449985 Remaining_Timer: 7308.15914499873  Watts: 364
total_time: 13693.4091449985 total threashold: 6385.25 Total_Speed: 314843.682270199 Total_processcounter: 26299 Threahold_Counter: 25541
Bike: Bike Finish time: 13693.6758009985 Remaining_Timer: 7308.17580099873  Watts: 364
total_time: 13693.6758009985 total threashold: 6385.5 Total_Speed: 315085.691133117 Total_processcounter: 26300 Threahold_Counter: 25542
Bike: @PathFollow3D@72 Finish time: 13693.6758009985 Remaining_Timer: 7308.17580099873  Watts: 364
total_time: 13693.6758009985 total threashold: 6385.5 Total_Speed: 315087.506911582 Total_processcounter: 26300 Threahold_Counter: 25542
Bike: @PathFollow3D@124 Finish time: 13693.6758009985 Remaining_Timer: 7308.17580099873  Watts: 364
total_time: 13693.6758009985 total threashold: 6385.5 Total_Speed: 314871.165276136 Total_processcounter: 26300 Threahold_Counter: 25542
Bike: @PathFollow3D@17 Finish time: 13727.0078009984 Remaining_Timer: 7310.2578009987  Watts: 364
total_time: 13727.0078009984 total threashold: 6416.75 Total_Speed: 315548.74097605 Total_processcounter: 26425 Threahold_Counter: 25667
Bike: @PathFollow3D@85 Finish time: 13731.5409529984 Remaining_Timer: 7310.5409529987  Watts: 364
total_time: 13731.5409529984 total threashold: 6421.0 Total_Speed: 315564.587186982 Total_processcounter: 26442 Threahold_Counter: 25684
Bike: @PathFollow3D@147 Finish time: 13739.5406329984 Remaining_Timer: 7311.04063299869  Watts: 364
total_time: 13739.5406329984 total threashold: 6428.5 Total_Speed: 315623.209745716 Total_processcounter: 26472 Threahold_Counter: 25714
Bike: @PathFollow3D@7 Finish time: 13773.4059449984 Remaining_Timer: 7313.15594499866  Watts: 373
total_time: 13773.4059449984 total threashold: 6460.25 Total_Speed: 317195.850797214 Total_processcounter: 26599 Threahold_Counter: 25841
Bike: @PathFollow3D@6 Finish time: 13791.0052409984 Remaining_Timer: 7314.25524099865  Watts: 373
total_time: 13791.0052409984 total threashold: 6476.75 Total_Speed: 317471.415567761 Total_processcounter: 26665 Threahold_Counter: 25907
Bike: @PathFollow3D@35 Finish time: 13792.8718329984 Remaining_Timer: 7314.37183299865  Watts: 364
total_time: 13792.8718329984 total threashold: 6478.5 Total_Speed: 317194.838049153 Total_processcounter: 26672 Threahold_Counter: 25914
Bike: @PathFollow3D@10 Finish time: 13825.6705209983 Remaining_Timer: 7316.42052099862  Watts: 364
total_time: 13825.6705209983 total threashold: 6509.25 Total_Speed: 317869.575860042 Total_processcounter: 26795 Threahold_Counter: 26037
Bike: @PathFollow3D@179 Finish time: 13825.6705209983 Remaining_Timer: 7316.42052099862  Watts: 364
total_time: 13825.6705209983 total threashold: 6509.25 Total_Speed: 317878.683616556 Total_processcounter: 26795 Threahold_Counter: 26037
Bike: @PathFollow3D@104 Finish time: 13839.2699769983 Remaining_Timer: 7317.26997699861  Watts: 364
total_time: 13839.2699769983 total threashold: 6522.0 Total_Speed: 318079.752147212 Total_processcounter: 26846 Threahold_Counter: 26088
Bike: @PathFollow3D@151 Finish time: 13839.2699769983 Remaining_Timer: 7317.26997699861  Watts: 364
total_time: 13839.2699769983 total threashold: 6522.0 Total_Speed: 318065.082059934 Total_processcounter: 26846 Threahold_Counter: 26088
Bike: @PathFollow3D@155 Finish time: 14106.9926009981 Remaining_Timer: 7333.99260099839  Watts: 373
total_time: 14106.9926009981 total threashold: 6773.0 Total_Speed: 325608.171301383 Total_processcounter: 27850 Threahold_Counter: 27092
Bike: @PathFollow3D@114 Finish time: 14107.2592569981 Remaining_Timer: 7334.00925699839  Watts: 373
total_time: 14107.2592569981 total threashold: 6773.25 Total_Speed: 325863.884205265 Total_processcounter: 27851 Threahold_Counter: 27093
Bike: @PathFollow3D@38 Finish time: 14108.8591929981 Remaining_Timer: 7334.10919299839  Watts: 364
total_time: 14108.8591929981 total threashold: 6774.75 Total_Speed: 325668.892482079 Total_processcounter: 27857 Threahold_Counter: 27099
Bike: @PathFollow3D@20 Finish time: 14109.1258489981 Remaining_Timer: 7334.12584899839  Watts: 364
total_time: 14109.1258489981 total threashold: 6775.0 Total_Speed: 325663.933035342 Total_processcounter: 27858 Threahold_Counter: 27100
Bike: @PathFollow3D@27 Finish time: 14109.1258489981 Remaining_Timer: 7334.12584899839  Watts: 364
total_time: 14109.1258489981 total threashold: 6775.0 Total_Speed: 325616.020734766 Total_processcounter: 27858 Threahold_Counter: 27100
Bike: @PathFollow3D@84 Finish time: 14109.1258489981 Remaining_Timer: 7334.12584899839  Watts: 364
total_time: 14109.1258489981 total threashold: 6775.0 Total_Speed: 325625.151974936 Total_processcounter: 27858 Threahold_Counter: 27100
Bike: @PathFollow3D@141 Finish time: 14109.1258489981 Remaining_Timer: 7334.12584899839  Watts: 364
total_time: 14109.1258489981 total threashold: 6775.0 Total_Speed: 325701.10299135 Total_processcounter: 27858 Threahold_Counter: 27100
Bike: @PathFollow3D@116 Finish time: 14113.3923449981 Remaining_Timer: 7334.39234499839  Watts: 373
total_time: 14113.3923449981 total threashold: 6779.0 Total_Speed: 325553.467279582 Total_processcounter: 27874 Threahold_Counter: 27116
Bike: @PathFollow3D@15 Finish time: 14140.3246009981 Remaining_Timer: 7336.07460099837  Watts: 373
total_time: 14140.3246009981 total threashold: 6804.25 Total_Speed: 326473.921169849 Total_processcounter: 27975 Threahold_Counter: 27217
Bike: @PathFollow3D@41 Finish time: 14141.9245369981 Remaining_Timer: 7336.17453699836  Watts: 364
total_time: 14141.9245369981 total threashold: 6805.75 Total_Speed: 326063.048769163 Total_processcounter: 27981 Threahold_Counter: 27223
Bike: @PathFollow3D@130 Finish time: 14141.9245369981 Remaining_Timer: 7336.17453699836  Watts: 364
total_time: 14141.9245369981 total threashold: 6805.75 Total_Speed: 326108.201607423 Total_processcounter: 27981 Threahold_Counter: 27223
Bike: @PathFollow3D@109 Finish time: 14143.5244729981 Remaining_Timer: 7336.27447299836  Watts: 364
total_time: 14143.5244729981 total threashold: 6807.25 Total_Speed: 325995.503052129 Total_processcounter: 27987 Threahold_Counter: 27229
Bike: @PathFollow3D@45 Finish time: 14144.0577849981 Remaining_Timer: 7336.30778499836  Watts: 364
total_time: 14144.0577849981 total threashold: 6807.75 Total_Speed: 326184.142824249 Total_processcounter: 27989 Threahold_Counter: 27231
Bike: @PathFollow3D@94 Finish time: 14181.1229689981 Remaining_Timer: 7338.62296899833  Watts: 373
total_time: 14181.1229689981 total threashold: 6842.5 Total_Speed: 326624.230872489 Total_processcounter: 28128 Threahold_Counter: 27370
Bike: @PathFollow3D@30 Finish time: 14182.9895609981 Remaining_Timer: 7338.73956099833  Watts: 364
total_time: 14182.9895609981 total threashold: 6844.25 Total_Speed: 326882.084413119 Total_processcounter: 28135 Threahold_Counter: 27377
Bike: @PathFollow3D@88 Finish time: 14183.2562169981 Remaining_Timer: 7338.75621699833  Watts: 373
total_time: 14183.2562169981 total threashold: 6844.5 Total_Speed: 326847.585248422 Total_processcounter: 28136 Threahold_Counter: 27378
Bike: @PathFollow3D@122 Finish time: 14198.188952998 Remaining_Timer: 7339.68895299832  Watts: 373
total_time: 14198.188952998 total threashold: 6858.5 Total_Speed: 327203.405988043 Total_processcounter: 28192 Threahold_Counter: 27434
Bike: @PathFollow3D@101 Finish time: 14201.922136998 Remaining_Timer: 7339.92213699832  Watts: 373
total_time: 14201.922136998 total threashold: 6862.0 Total_Speed: 327137.288677063 Total_processcounter: 28206 Threahold_Counter: 27448
Bike: @PathFollow3D@107 Finish time: 14212.588376998 Remaining_Timer: 7340.58837699831  Watts: 373
total_time: 14212.588376998 total threashold: 6872.0 Total_Speed: 327239.412344197 Total_processcounter: 28246 Threahold_Counter: 27488
Bike: @PathFollow3D@9 Finish time: 14247.786968998 Remaining_Timer: 7342.78696899828  Watts: 364
total_time: 14247.786968998 total threashold: 6905.0 Total_Speed: 327740.60047245 Total_processcounter: 28378 Threahold_Counter: 27620
Bike: @PathFollow3D@90 Finish time: 14247.786968998 Remaining_Timer: 7342.78696899828  Watts: 364
total_time: 14247.786968998 total threashold: 6905.0 Total_Speed: 328025.391311806 Total_processcounter: 28378 Threahold_Counter: 27620
Bike: @PathFollow3D@161 Finish time: 14247.786968998 Remaining_Timer: 7342.78696899828  Watts: 364
total_time: 14247.786968998 total threashold: 6905.0 Total_Speed: 327769.98004046 Total_processcounter: 28378 Threahold_Counter: 27620
Bike: @PathFollow3D@91 Finish time: 14258.453208998 Remaining_Timer: 7343.45320899827  Watts: 364
total_time: 14258.453208998 total threashold: 6915.0 Total_Speed: 328122.69268039 Total_processcounter: 28418 Threahold_Counter: 27660
Bike: @PathFollow3D@178 Finish time: 14265.652920998 Remaining_Timer: 7343.90292099826  Watts: 364
total_time: 14265.652920998 total threashold: 6921.75 Total_Speed: 328554.103664002 Total_processcounter: 28445 Threahold_Counter: 27687
Bike: @PathFollow3D@81 Finish time: 14274.185912998 Remaining_Timer: 7344.43591299826  Watts: 373
total_time: 14274.185912998 total threashold: 6929.75 Total_Speed: 328491.827586329 Total_processcounter: 28477 Threahold_Counter: 27719
Bike: @PathFollow3D@33 Finish time: 14287.252056998 Remaining_Timer: 7345.25205699825  Watts: 373
total_time: 14287.252056998 total threashold: 6942.0 Total_Speed: 328892.889320908 Total_processcounter: 28526 Threahold_Counter: 27768
Bike: @PathFollow3D@66 Finish time: 14302.451448998 Remaining_Timer: 7346.20144899823  Watts: 373
total_time: 14302.451448998 total threashold: 6956.25 Total_Speed: 329080.108713115 Total_processcounter: 28583 Threahold_Counter: 27825
Bike: @PathFollow3D@52 Finish time: 14453.3787449978 Remaining_Timer: 7355.62874499811  Watts: 382
total_time: 14453.3787449978 total threashold: 7097.75 Total_Speed: 335134.275603551 Total_processcounter: 29149 Threahold_Counter: 28391
Bike: @PathFollow3D@37 Finish time: 14456.8452729978 Remaining_Timer: 7355.84527299811  Watts: 364
total_time: 14456.8452729978 total threashold: 7101.0 Total_Speed: 332363.398321772 Total_processcounter: 29162 Threahold_Counter: 28404
Bike: @PathFollow3D@50 Finish time: 14456.8452729978 Remaining_Timer: 7355.84527299811  Watts: 364
total_time: 14456.8452729978 total threashold: 7101.0 Total_Speed: 333278.31722602 Total_processcounter: 29162 Threahold_Counter: 28404
Bike: @PathFollow3D@16 Finish time: 14472.5779769978 Remaining_Timer: 7356.8279769981  Watts: 364
total_time: 14472.5779769978 total threashold: 7115.75 Total_Speed: 333487.449641209 Total_processcounter: 29221 Threahold_Counter: 28463
Bike: @PathFollow3D@95 Finish time: 14478.1777529978 Remaining_Timer: 7357.17775299809  Watts: 364
total_time: 14478.1777529978 total threashold: 7121.0 Total_Speed: 332875.387353459 Total_processcounter: 29242 Threahold_Counter: 28484
Bike: @PathFollow3D@113 Finish time: 14478.1777529978 Remaining_Timer: 7357.17775299809  Watts: 364
total_time: 14478.1777529978 total threashold: 7121.0 Total_Speed: 332813.092598933 Total_processcounter: 29242 Threahold_Counter: 28484
Bike: @PathFollow3D@24 Finish time: 14484.8441529978 Remaining_Timer: 7357.59415299809  Watts: 364
total_time: 14484.8441529978 total threashold: 7127.25 Total_Speed: 333306.18712271 Total_processcounter: 29267 Threahold_Counter: 28509
Bike: @PathFollow3D@93 Finish time: 14485.6441209978 Remaining_Timer: 7357.64412099809  Watts: 364
total_time: 14485.6441209978 total threashold: 7128.0 Total_Speed: 333560.767049947 Total_processcounter: 29270 Threahold_Counter: 28512
Bike: @PathFollow3D@11 Finish time: 14608.8391929977 Remaining_Timer: 7365.33919299799  Watts: 364
total_time: 14608.8391929977 total threashold: 7243.5 Total_Speed: 337451.181499892 Total_processcounter: 29732 Threahold_Counter: 28974
--- Debugging process stopped ---

"""
# Parse all finish times
times = [float(m) for m in re.findall(r"Finish time: ([\d.]+)", data)]

# Group into sequences where the gap between consecutive times is < 0.85
GAP = 1.00
sequences = []
current_seq = [times[0]]

for t in times[1:]:
    if t - current_seq[-1] < GAP:
        current_seq.append(t)
    else:
        sequences.append(current_seq)
        current_seq = [t]
sequences.append(current_seq)

# Print results
print(f"Found {len(sequences)} sequences (gap threshold: {GAP}):\n")
for i, seq in enumerate(sequences, 1):
    print(f"  Sequence {i:2d}: {len(seq):3d} bike(s)  |  {seq[0]:.0f}")# → {seq[-1]:.2f}")
