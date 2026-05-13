import re

data = """Godot Engine v4.6.1.stable.official.14d19694e - https://godotengine.org
OpenGL API 3.3.0 - Build 32.0.101.7026 - Compatibility - Using Device: Intel - Intel(R) Iris(R) Xe Graphics

Min: -9 Max: 18
Bike: @PathFollow3D@6 Finish time: 15235.5145163253 Watt: 391
Max_speed: 23.6694224724112
Bike: @PathFollow3D@16 Finish time: 15235.5145163253 Watt: 391
Max_speed: 23.524963285847
Bike: @PathFollow3D@89 Finish time: 15235.5145163253 Watt: 391
Max_speed: 23.992540253527
Bike: @PathFollow3D@104 Finish time: 15235.5145163253 Watt: 391
Max_speed: 24.0477435870526
Bike: @PathFollow3D@107 Finish time: 15235.5145163253 Watt: 391
Max_speed: 24.6384033681285
Bike: @PathFollow3D@118 Finish time: 15235.5145163253 Watt: 391
Max_speed: 24.3123367766152
Bike: @PathFollow3D@126 Finish time: 15235.5145163253 Watt: 391
Max_speed: 23.9649392423156
Bike: @PathFollow3D@134 Finish time: 15235.5145163253 Watt: 391
Max_speed: 24.9342386192938
Bike: @PathFollow3D@164 Finish time: 15235.5145163253 Watt: 391
Max_speed: 23.9142234460059
Bike: @PathFollow3D@15 Finish time: 15243.7808523253 Watt: 391
Max_speed: 23.7800219716102
Bike: @PathFollow3D@19 Finish time: 15243.7808523253 Watt: 391
Max_speed: 23.652957950767
Bike: @PathFollow3D@37 Finish time: 15243.7808523253 Watt: 391
Max_speed: 23.3645759572895
Bike: @PathFollow3D@110 Finish time: 15243.7808523253 Watt: 391
Max_speed: 23.8515603640222
Bike: @PathFollow3D@161 Finish time: 15243.7808523253 Watt: 391
Max_speed: 23.8265321579818
Bike: @PathFollow3D@165 Finish time: 15265.9133003252 Watt: 391
Max_speed: 23.9358437480918
Bike: @PathFollow3D@42 Finish time: 15274.7129483252 Watt: 391
Max_speed: 22.8843403185415
Bike: @PathFollow3D@173 Finish time: 15280.5793803252 Watt: 391
Max_speed: 24.4290095151416
Bike: @PathFollow3D@39 Finish time: 15282.9792843252 Watt: 391
Max_speed: 22.8396968293182
Bike: @PathFollow3D@81 Finish time: 15282.9792843252 Watt: 391
Max_speed: 23.686924532593
Bike: @PathFollow3D@24 Finish time: 15283.2459403252 Watt: 391
Max_speed: 23.9659852263909
Bike: @PathFollow3D@151 Finish time: 15284.5792203252 Watt: 391
Max_speed: 24.9000160840013
Bike: @PathFollow3D@40 Finish time: 15288.5790603252 Watt: 391
Max_speed: 24.5932479237318
Bike: @PathFollow3D@140 Finish time: 15290.7123083252 Watt: 391
Max_speed: 23.6146627615723
Bike: @PathFollow3D@58 Finish time: 15293.6455243252 Watt: 391
Max_speed: 23.8392581465587
Bike: @PathFollow3D@5 Finish time: 15296.0454283252 Watt: 391
Max_speed: 23.0395536837594
Bike: @PathFollow3D@7 Finish time: 15296.0454283252 Watt: 391
Max_speed: 23.9039148009913
Bike: @PathFollow3D@13 Finish time: 15296.0454283252 Watt: 391
Max_speed: 23.9170528458781
Bike: @PathFollow3D@47 Finish time: 15301.1118923252 Watt: 391
Max_speed: 24.028334095548
Bike: @PathFollow3D@129 Finish time: 15301.1118923252 Watt: 391
Max_speed: 24.2557230712356
Bike: @PathFollow3D@175 Finish time: 15301.1118923252 Watt: 391
Max_speed: 23.8584252897572
Bike: @PathFollow3D@4 Finish time: 15324.0443083252 Watt: 391
Max_speed: 23.6369811089361
Bike: @PathFollow3D@167 Finish time: 15325.1109323252 Watt: 391
Max_speed: 24.2555980484869
Bike: @PathFollow3D@153 Finish time: 15330.9773643252 Watt: 391
Max_speed: 24.9437749849073
Bike: @PathFollow3D@158 Finish time: 15347.7766923252 Watt: 391
Max_speed: 23.1529311893242
Bike: @PathFollow3D@125 Finish time: 15352.3098443252 Watt: 391
Max_speed: 23.6238587838535
Bike: @PathFollow3D@29 Finish time: 15359.2429003252 Watt: 391
Max_speed: 22.9535497912138
Bike: @PathFollow3D@95 Finish time: 15375.7755723251 Watt: 391
Max_speed: 24.1692264614325
Bike: @PathFollow3D@103 Finish time: 15375.7755723251 Watt: 391
Max_speed: 23.8286761841645
Bike: @PathFollow3D@145 Finish time: 15375.7755723251 Watt: 391
Max_speed: 23.1900100665077
Bike: @PathFollow3D@69 Finish time: 15383.2419403251 Watt: 382
Max_speed: 24.7421152401704
Bike: @PathFollow3D@80 Finish time: 15387.5084363251 Watt: 382
Max_speed: 24.1328287262947
Bike: @PathFollow3D@119 Finish time: 15388.5750603251 Watt: 391
Max_speed: 23.0390376623194
Bike: @PathFollow3D@121 Finish time: 15388.5750603251 Watt: 391
Max_speed: 24.4604601196108
Bike: @PathFollow3D@159 Finish time: 15389.1083723251 Watt: 382
Max_speed: 24.2190448399172
Bike: @PathFollow3D@72 Finish time: 15391.5082763251 Watt: 391
Max_speed: 23.8478109297348
Bike: @PathFollow3D@90 Finish time: 15391.5082763251 Watt: 391
Max_speed: 24.3130997764267
Bike: Bike Finish time: 15398.1746763251 Watt: 382
Max_speed: 24.4989210143347
Bike: @PathFollow3D@86 Finish time: 15398.9746443251 Watt: 382
Max_speed: 24.1588521823295
Bike: @PathFollow3D@113 Finish time: 15399.2413003251 Watt: 382
Max_speed: 24.0877142275295
Bike: @PathFollow3D@135 Finish time: 15400.5745803251 Watt: 382
Max_speed: 24.328632429976
Bike: @PathFollow3D@44 Finish time: 15401.6412043251 Watt: 382
Max_speed: 24.0960280922368
Bike: @PathFollow3D@136 Finish time: 15402.7078283251 Watt: 382
Max_speed: 24.5108128588827
Bike: @PathFollow3D@54 Finish time: 15430.4400523251 Watt: 382
Max_speed: 24.3063131676731
Bike: @PathFollow3D@178 Finish time: 15431.5066763251 Watt: 382
Max_speed: 24.3025180634876
Bike: @PathFollow3D@28 Finish time: 15434.1732363251 Watt: 382
Max_speed: 23.5691024168667
Bike: @PathFollow3D@99 Finish time: 15441.1062923251 Watt: 382
Max_speed: 23.6036155484609
Bike: @PathFollow3D@149 Finish time: 15466.1719563251 Watt: 382
Max_speed: 23.5851831770784
Bike: @PathFollow3D@91 Finish time: 15469.1051723251 Watt: 382
Max_speed: 24.4404922514808
Bike: @PathFollow3D@32 Finish time: 15470.9717643251 Watt: 382
Max_speed: 23.9307231400035
Bike: @PathFollow3D@154 Finish time: 15478.7047883251 Watt: 391
Max_speed: 23.9745184587518
Bike: @PathFollow3D@97 Finish time: 15488.8377163251 Watt: 382
Max_speed: 24.5112658959018
Bike: @PathFollow3D@109 Finish time: 15490.1709963251 Watt: 382
Max_speed: 23.8875942577319
Bike: @PathFollow3D@73 Finish time: 15491.2376203251 Watt: 382
Max_speed: 23.9531382165638
Bike: @PathFollow3D@120 Finish time: 15493.370868325 Watt: 391
Max_speed: 23.829369685888
Bike: @PathFollow3D@62 Finish time: 15496.037428325 Watt: 382
Max_speed: 24.300332086495
Bike: @PathFollow3D@48 Finish time: 15497.904020325 Watt: 391
Max_speed: 23.9682651944702
Bike: @PathFollow3D@87 Finish time: 15506.170356325 Watt: 382
Max_speed: 24.116951725509
Bike: @PathFollow3D@22 Finish time: 15509.903540325 Watt: 382
Max_speed: 24.0318788045883
Bike: @PathFollow3D@27 Finish time: 15513.370068325 Watt: 382
Max_speed: 24.1315267601958
Bike: @PathFollow3D@133 Finish time: 15518.169876325 Watt: 382
Max_speed: 23.5869727630939
Bike: @PathFollow3D@64 Finish time: 15520.036468325 Watt: 382
Max_speed: 24.3237295370662
Bike: @PathFollow3D@10 Finish time: 15523.236340325 Watt: 382
Max_speed: 23.9025465784651
Bike: @PathFollow3D@148 Finish time: 15528.036148325 Watt: 382
Max_speed: 24.2932145254452
Bike: @PathFollow3D@162 Finish time: 15531.236020325 Watt: 373
Max_speed: 23.8709441094629
Bike: @PathFollow3D@98 Finish time: 15558.434932325 Watt: 382
Max_speed: 23.8253931387941
Bike: @PathFollow3D@142 Finish time: 15565.101332325 Watt: 373
Max_speed: 23.8038908350673
Bike: @PathFollow3D@180 Finish time: 15576.567540325 Watt: 373
Max_speed: 24.6755060174997
Bike: @PathFollow3D@105 Finish time: 15597.900020325 Watt: 373
Max_speed: 23.3813853474358
Bike: @PathFollow3D@112 Finish time: 15601.099892325 Watt: 382
Max_speed: 24.1094539989596
Bike: @PathFollow3D@56 Finish time: 15612.032788325 Watt: 382
Max_speed: 24.3900986121514
Bike: @PathFollow3D@156 Finish time: 15614.166036325 Watt: 382
Max_speed: 23.1125656510978
Bike: @PathFollow3D@115 Finish time: 15617.8992203249 Watt: 373
Max_speed: 23.8640697923441
Bike: @PathFollow3D@116 Finish time: 15622.9656843249 Watt: 382
Max_speed: 23.3539201476594
Bike: @PathFollow3D@128 Finish time: 15624.8544985472 Watt: 373
Max_speed: 23.8987249202055
Bike: @PathFollow3D@61 Finish time: 15631.8988149916 Watt: 391
Max_speed: 23.9468780400209
Bike: @PathFollow3D@60 Finish time: 15632.6988149916 Watt: 373
Max_speed: 23.918977180715
Bike: @PathFollow3D@138 Finish time: 15640.9654816583 Watt: 373
Max_speed: 24.7935021284119
Bike: @PathFollow3D@78 Finish time: 15641.7654816583 Watt: 382
Max_speed: 23.4335147867706
Bike: @PathFollow3D@179 Finish time: 15643.6321483249 Watt: 373
Max_speed: 23.8458099787263
Bike: @PathFollow3D@141 Finish time: 15656.4321483249 Watt: 373
Max_speed: 23.8958126245765
Bike: @PathFollow3D@106 Finish time: 15656.9654816582 Watt: 382
Max_speed: 23.8630031044051
Bike: @PathFollow3D@50 Finish time: 15666.2988149916 Watt: 373
Max_speed: 23.7288898000423
Bike: @PathFollow3D@163 Finish time: 15670.8321483249 Watt: 373
Max_speed: 23.3584621380443
Bike: @PathFollow3D@35 Finish time: 15681.4988149916 Watt: 373
Max_speed: 23.8620274670312
Bike: @PathFollow3D@174 Finish time: 15683.3654816582 Watt: 382
Max_speed: 23.9016604281662
Bike: @PathFollow3D@92 Finish time: 15711.6321483249 Watt: 382
Max_speed: 24.2312914109128
Bike: @PathFollow3D@93 Finish time: 15717.2321483249 Watt: 382
Max_speed: 24.1636818687035
Bike: @PathFollow3D@79 Finish time: 15723.6321483249 Watt: 373
Max_speed: 23.8184996326352
Bike: @PathFollow3D@41 Finish time: 15727.6321483248 Watt: 373
Max_speed: 25.3518007652117
Bike: @PathFollow3D@83 Finish time: 15729.2321483248 Watt: 373
Max_speed: 23.3086415534056
Bike: @PathFollow3D@152 Finish time: 15730.2988149915 Watt: 382
Max_speed: 23.6372364247272
Bike: @PathFollow3D@143 Finish time: 15731.6321483248 Watt: 373
Max_speed: 23.672158199661
Bike: @PathFollow3D@49 Finish time: 15733.7654816582 Watt: 373
Max_speed: 23.6869145757957
Bike: @PathFollow3D@33 Finish time: 15737.7654816582 Watt: 373
Max_speed: 24.1733434729284
Bike: @PathFollow3D@43 Finish time: 15751.0988149915 Watt: 373
Max_speed: 23.8450090487539
Bike: @PathFollow3D@53 Finish time: 15757.2321483248 Watt: 373
Max_speed: 22.7922198367022
Bike: @PathFollow3D@137 Finish time: 15766.0321483248 Watt: 373
Max_speed: 23.3960148197239
Bike: @PathFollow3D@77 Finish time: 15769.4988149915 Watt: 382
Max_speed: 23.700267371087
Bike: @PathFollow3D@88 Finish time: 15778.2988149915 Watt: 373
Max_speed: 22.7965215219649
Bike: @PathFollow3D@65 Finish time: 15784.4321483248 Watt: 373
Max_speed: 23.5913169077085
Bike: @PathFollow3D@76 Finish time: 15795.6321483248 Watt: 373
Max_speed: 23.9161430723904
Bike: @PathFollow3D@46 Finish time: 15823.8988149914 Watt: 373
Max_speed: 23.4127319511541
Bike: @PathFollow3D@101 Finish time: 15846.5654816581 Watt: 373
Max_speed: 23.4990905413258
Bike: @PathFollow3D@85 Finish time: 15873.2321483247 Watt: 373
Max_speed: 24.8228001965151
Bike: @PathFollow3D@102 Finish time: 15878.0321483247 Watt: 373
Max_speed: 23.538363478587
Bike: @PathFollow3D@71 Finish time: 15888.4321483247 Watt: 373
Max_speed: 23.7189159630648
Bike: @PathFollow3D@14 Finish time: 15889.765481658 Watt: 373
Max_speed: 23.4366214619156
Bike: @PathFollow3D@18 Finish time: 15889.765481658 Watt: 373
Max_speed: 23.3356808007033
Bike: @PathFollow3D@146 Finish time: 15891.6321483247 Watt: 373
Max_speed: 23.4578851710216
Bike: @PathFollow3D@57 Finish time: 15907.8988149913 Watt: 373
Max_speed: 22.7890734778988
Bike: @PathFollow3D@82 Finish time: 15920.4321483247 Watt: 373
Max_speed: 23.7834142771181
Bike: @PathFollow3D@157 Finish time: 15943.365481658 Watt: 373
Max_speed: 23.4423769859828
Bike: @PathFollow3D@114 Finish time: 15948.165481658 Watt: 373
Max_speed: 22.8672629627785
Bike: @PathFollow3D@132 Finish time: 15952.165481658 Watt: 373
Max_speed: 23.0416921320082
Bike: @PathFollow3D@111 Finish time: 15952.4321483246 Watt: 373
Max_speed: 23.7021414855531
Bike: @PathFollow3D@70 Finish time: 15952.965481658 Watt: 364
Max_speed: 24.5024819228647
Bike: @PathFollow3D@122 Finish time: 15956.4321483246 Watt: 373
Max_speed: 23.6820254389301
Bike: @PathFollow3D@100 Finish time: 15970.565481658 Watt: 382
Max_speed: 24.0719941951244
Bike: @PathFollow3D@172 Finish time: 15974.0321483246 Watt: 364
Max_speed: 23.6609168214924
Bike: @PathFollow3D@11 Finish time: 15977.2321483246 Watt: 373
Max_speed: 24.2503618052795
Bike: @PathFollow3D@108 Finish time: 15979.6321483246 Watt: 373
Max_speed: 23.3802585582052
Bike: @PathFollow3D@21 Finish time: 15984.1654816579 Watt: 373
Max_speed: 23.057847257837
Bike: @PathFollow3D@144 Finish time: 15991.8988149913 Watt: 373
Max_speed: 23.5080651592549
Bike: @PathFollow3D@30 Finish time: 15996.6988149913 Watt: 373
Max_speed: 22.7525082405735
Bike: @PathFollow3D@67 Finish time: 16009.4988149913 Watt: 382
Max_speed: 23.2058799822934
Bike: @PathFollow3D@169 Finish time: 16009.7654816579 Watt: 373
Max_speed: 22.939808002931
Bike: @PathFollow3D@23 Finish time: 16010.0321483246 Watt: 373
Max_speed: 24.0354962000536
Bike: @PathFollow3D@139 Finish time: 16011.3654816579 Watt: 364
Max_speed: 24.7512201706115
Bike: @PathFollow3D@127 Finish time: 16012.6988149913 Watt: 373
Max_speed: 22.9049910179382
Bike: @PathFollow3D@84 Finish time: 16018.0321483246 Watt: 382
Max_speed: 22.9057957170557
Bike: @PathFollow3D@52 Finish time: 16019.8988149912 Watt: 364
Max_speed: 24.1063885222793
Bike: @PathFollow3D@176 Finish time: 16027.6321483246 Watt: 364
Max_speed: 24.4937738929047
Bike: @PathFollow3D@68 Finish time: 16068.1654816579 Watt: 364
Max_speed: 24.5200564355901
Bike: @PathFollow3D@160 Finish time: 16099.6321483245 Watt: 364
Max_speed: 24.0716789364791
Bike: @PathFollow3D@20 Finish time: 16106.2988149912 Watt: 373
Max_speed: 23.2851755348464
Bike: @PathFollow3D@25 Finish time: 16118.8321483245 Watt: 364
Max_speed: 25.2169431360341
Bike: @PathFollow3D@130 Finish time: 16148.4321483245 Watt: 373
Max_speed: 24.7815848802499
Bike: @PathFollow3D@26 Finish time: 16153.4988149911 Watt: 364
Max_speed: 23.0986465445146
Bike: @PathFollow3D@123 Finish time: 16156.9654816578 Watt: 364
Max_speed: 23.8254687009496
Bike: @PathFollow3D@31 Finish time: 16159.6321483245 Watt: 364
Max_speed: 23.7923015264994
Bike: @PathFollow3D@166 Finish time: 16161.2321483245 Watt: 364
Max_speed: 24.442610720994
Bike: @PathFollow3D@66 Finish time: 16176.4321483244 Watt: 364
Max_speed: 24.9014720784658
Bike: @PathFollow3D@117 Finish time: 16190.5654816578 Watt: 364
Max_speed: 24.8831774861488
Bike: @PathFollow3D@147 Finish time: 16212.4321483244 Watt: 364
Max_speed: 23.1288766656526
Bike: @PathFollow3D@34 Finish time: 16246.298814991 Watt: 364
Max_speed: 24.2892676550497
Bike: @PathFollow3D@155 Finish time: 16313.7654816576 Watt: 373
Max_speed: 23.3866545777374
Bike: @PathFollow3D@94 Finish time: 16318.0321483243 Watt: 364
Max_speed: 23.4960556801681
Bike: @PathFollow3D@170 Finish time: 16419.6321483242 Watt: 364
Max_speed: 23.0076298920136
Bike: @PathFollow3D@9 Finish time: 16442.0321483242 Watt: 364
Max_speed: 24.3801395806364
Bike: @PathFollow3D@168 Finish time: 16456.1654816575 Watt: 364
Max_speed: 23.0434594896423
Bike: @PathFollow3D@131 Finish time: 16468.1654816575 Watt: 364
Max_speed: 22.6995717064856
Bike: @PathFollow3D@63 Finish time: 16472.4321483242 Watt: 364
Max_speed: 24.9705887585263
Bike: @PathFollow3D@171 Finish time: 16497.7654816575 Watt: 364
Max_speed: 25.3135527940113
Bike: @PathFollow3D@177 Finish time: 16544.1654816574 Watt: 364
Max_speed: 22.6992405206781
Bike: @PathFollow3D@38 Finish time: 16551.6321483241 Watt: 364
Max_speed: 23.2529781120601
Bike: @PathFollow3D@12 Finish time: 16567.6321483241 Watt: 364
Max_speed: 22.6996239055503
Bike: @PathFollow3D@51 Finish time: 16603.0988149907 Watt: 364
Max_speed: 23.3807747001944
Bike: @PathFollow3D@59 Finish time: 16605.7654816574 Watt: 364
Max_speed: 22.7646128395106
Bike: @PathFollow3D@74 Finish time: 16638.2988149907 Watt: 364
Max_speed: 22.7006641326654
Bike: @PathFollow3D@36 Finish time: 16644.432148324 Watt: 364
Max_speed: 22.7106389455823
Bike: @PathFollow3D@75 Finish time: 16665.232148324 Watt: 364
Max_speed: 22.8360652821598
Bike: @PathFollow3D@8 Finish time: 16674.032148324 Watt: 364
Max_speed: 22.7001396626031
Bike: @PathFollow3D@182 Finish time: 16679.632148324 Watt: 364
Max_speed: 22.6999852881092
Bike: @PathFollow3D@55 Finish time: 16704.1654816573 Watt: 364
Max_speed: 22.7319927936682
Bike: @PathFollow3D@181 Finish time: 16705.7654816573 Watt: 364
Max_speed: 22.6991991370689
Bike: @PathFollow3D@17 Finish time: 16714.032148324 Watt: 364
Max_speed: 22.6992404867764
Bike: @PathFollow3D@45 Finish time: 16720.6988149906 Watt: 364
Max_speed: 22.6995021691902
Bike: @PathFollow3D@96 Finish time: 16728.6988149906 Watt: 364
Max_speed: 22.6991329489824
Bike: @PathFollow3D@124 Finish time: 16734.8321483239 Watt: 364
Max_speed: 22.6989771912333
Bike: @PathFollow3D@150 Finish time: 16770.8321483239 Watt: 364
Max_speed: 22.6989336480662
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
