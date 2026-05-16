import re

data = """
Bike: @PathFollow3D@62 Finish time: 15538.0333332755
Bike: @PathFollow3D@156 Finish time: 15538.5666666088
Bike: @PathFollow3D@43 Finish time: 15539.2666666088
Bike: @PathFollow3D@48 Finish time: 15539.3333332755
Bike: @PathFollow3D@6 Finish time: 15539.7999999422
sim_time=15540.0333332755 wall_time=16326.339 ratio=0.95183821267435 clusters=59
Bike: @PathFollow3D@14 Finish time: 15540.3666666088
Bike: @PathFollow3D@105 Finish time: 15540.5333332755
Bike: @PathFollow3D@82 Finish time: 15541.4999999421
Bike: @PathFollow3D@7 Finish time: 15542.8999999421
Bike: @PathFollow3D@27 Finish time: 15543.0666666088
Bike: @PathFollow3D@28 Finish time: 15543.4333332754
Bike: @PathFollow3D@116 Finish time: 15544.1333332754
Bike: @PathFollow3D@160 Finish time: 15544.6333332754
Bike: @PathFollow3D@46 Finish time: 15545.4666666087
Bike: @PathFollow3D@50 Finish time: 15545.7333332754
Bike: @PathFollow3D@127 Finish time: 15545.7333332754
Bike: @PathFollow3D@104 Finish time: 15546.1333332754
Bike: @PathFollow3D@90 Finish time: 15547.7333332754
Bike: @PathFollow3D@111 Finish time: 15547.999999942
Bike: @PathFollow3D@157 Finish time: 15548.2333332754
Bike: @PathFollow3D@18 Finish time: 15548.5666666087
Bike: @PathFollow3D@72 Finish time: 15548.699999942
Bike: @PathFollow3D@51 Finish time: 15548.799999942
Bike: @PathFollow3D@22 Finish time: 15549.0333332754
Bike: @PathFollow3D@84 Finish time: 15549.2666666087
Bike: @PathFollow3D@131 Finish time: 15549.5666666087
Bike: @PathFollow3D@63 Finish time: 15549.6333332754
Bike: @PathFollow3D@64 Finish time: 15549.9666666087
Bike: @PathFollow3D@172 Finish time: 15550.7666666087
Bike: @PathFollow3D@107 Finish time: 15552.0666666086
Bike: @PathFollow3D@37 Finish time: 15552.2666666086
Bike: @PathFollow3D@41 Finish time: 15552.3333332753
Bike: @PathFollow3D@136 Finish time: 15552.4333332753
Bike: @PathFollow3D@123 Finish time: 15552.5333332753
Bike: @PathFollow3D@66 Finish time: 15552.7666666086
Bike: @PathFollow3D@135 Finish time: 15552.7666666086
Bike: @PathFollow3D@42 Finish time: 15552.8666666086
Bike: @PathFollow3D@154 Finish time: 15552.8666666086
Bike: @PathFollow3D@44 Finish time: 15552.9666666086
Bike: @PathFollow3D@52 Finish time: 15552.9666666086
Bike: @PathFollow3D@57 Finish time: 15552.9666666086
Bike: @PathFollow3D@68 Finish time: 15552.9666666086
Bike: @PathFollow3D@109 Finish time: 15552.9666666086
Bike: @PathFollow3D@115 Finish time: 15552.9666666086
Bike: @PathFollow3D@158 Finish time: 15552.9666666086
Bike: @PathFollow3D@153 Finish time: 15553.099999942
Bike: @PathFollow3D@69 Finish time: 15553.499999942
Bike: @PathFollow3D@170 Finish time: 15553.499999942
Bike: @PathFollow3D@11 Finish time: 15553.6333332753
Bike: @PathFollow3D@113 Finish time: 15553.7333332753
Bike: @PathFollow3D@167 Finish time: 15553.7333332753
sim_time=15570.0333332751 wall_time=16356.444 ratio=0.95192043779657 clusters=49
sim_time=15600.0333332746 wall_time=16386.738 ratio=0.9519913806686 clusters=49
sim_time=15630.0333332742 wall_time=16416.946 ratio=0.95206704908904 clusters=49
sim_time=15660.0333332737 wall_time=16446.929 ratio=0.95215546521018 clusters=49
Bike: @PathFollow3D@121 Finish time: 15682.7333332734
Bike: @PathFollow3D@71 Finish time: 15683.4333332734
Bike: @PathFollow3D@173 Finish time: 15684.2333332734
Bike: @PathFollow3D@164 Finish time: 15684.5333332734
Bike: @PathFollow3D@23 Finish time: 15684.7666666067
Bike: @PathFollow3D@103 Finish time: 15686.7666666067
Bike: @PathFollow3D@163 Finish time: 15687.59999994
Bike: @PathFollow3D@100 Finish time: 15689.7666666066
sim_time=15690.0333332733 wall_time=16476.925 ratio=0.95224280824689 clusters=42
Bike: @PathFollow3D@36 Finish time: 15690.69999994
Bike: @PathFollow3D@56 Finish time: 15691.2666666066
Bike: @PathFollow3D@147 Finish time: 15691.7666666066
Bike: @PathFollow3D@12 Finish time: 15692.2333332733
Bike: @PathFollow3D@99 Finish time: 15692.4333332733
Bike: @PathFollow3D@53 Finish time: 15693.1999999399
Bike: @PathFollow3D@134 Finish time: 15693.7666666066
Bike: @PathFollow3D@148 Finish time: 15698.7666666065
Bike: @PathFollow3D@80 Finish time: 15700.6999999398
Bike: @PathFollow3D@169 Finish time: 15706.2333332731
Bike: @PathFollow3D@129 Finish time: 15706.4333332731
Bike: @PathFollow3D@32 Finish time: 15706.7666666064
Bike: @PathFollow3D@106 Finish time: 15706.9333332731
Bike: @PathFollow3D@9 Finish time: 15707.1999999397
Bike: @PathFollow3D@162 Finish time: 15707.2666666064
Bike: @PathFollow3D@132 Finish time: 15707.5999999397
Bike: @PathFollow3D@59 Finish time: 15707.9666666064
Bike: @PathFollow3D@141 Finish time: 15708.5999999397
Bike: @PathFollow3D@73 Finish time: 15708.633333273
Bike: @PathFollow3D@98 Finish time: 15708.7666666064
Bike: @PathFollow3D@180 Finish time: 15708.7666666064
Bike: @PathFollow3D@47 Finish time: 15709.033333273
Bike: @PathFollow3D@60 Finish time: 15709.2666666064
Bike: @PathFollow3D@89 Finish time: 15709.2666666064
Bike: @PathFollow3D@175 Finish time: 15709.7666666064
Bike: @PathFollow3D@101 Finish time: 15710.133333273
Bike: @PathFollow3D@114 Finish time: 15710.133333273
Bike: @PathFollow3D@130 Finish time: 15710.133333273
Bike: @PathFollow3D@97 Finish time: 15710.2666666063
Bike: @PathFollow3D@16 Finish time: 15710.7666666063
sim_time=15720.0333332729 wall_time=16507.473 ratio=0.95229798850938 clusters=34
sim_time=15750.0333332724 wall_time=16537.533 ratio=0.95238106755539 clusters=34
sim_time=15780.033333272 wall_time=16567.476 ratio=0.95247057145409 clusters=34
sim_time=15810.0333332716 wall_time=16597.72 ratio=0.95254247771812 clusters=33
Bike: @PathFollow3D@15 Finish time: 15834.6333332712
Bike: @PathFollow3D@95 Finish time: 15835.5999999379
Bike: @PathFollow3D@86 Finish time: 15836.5333332712
Bike: @PathFollow3D@174 Finish time: 15838.1999999378
sim_time=15840.0333332711 wall_time=16627.698 ratio=0.95262936175958 clusters=30
Bike: @PathFollow3D@171 Finish time: 15840.4666666045
Bike: @PathFollow3D@49 Finish time: 15841.9333332711
Bike: @PathFollow3D@119 Finish time: 15842.1999999378
Bike: @PathFollow3D@40 Finish time: 15842.7333332711
Bike: @PathFollow3D@58 Finish time: 15843.5999999377
Bike: @PathFollow3D@125 Finish time: 15844.0666666044
Bike: @PathFollow3D@139 Finish time: 15844.6999999377
Bike: @PathFollow3D@24 Finish time: 15846.1999999377
Bike: @PathFollow3D@126 Finish time: 15848.7999999377
Bike: @PathFollow3D@31 Finish time: 15848.933333271
Bike: @PathFollow3D@149 Finish time: 15848.933333271
Bike: @PathFollow3D@33 Finish time: 15849.6666666043
Bike: @PathFollow3D@87 Finish time: 15852.5666666043
Bike: @PathFollow3D@165 Finish time: 15853.1999999376
Bike: @PathFollow3D@67 Finish time: 15853.6999999376
Bike: @PathFollow3D@21 Finish time: 15854.9333332709
Bike: @PathFollow3D@29 Finish time: 15857.0999999375
Bike: @PathFollow3D@55 Finish time: 15857.1666666042
Bike: @PathFollow3D@61 Finish time: 15857.4333332709
Bike: @PathFollow3D@91 Finish time: 15858.0999999375
Bike: @PathFollow3D@181 Finish time: 15858.2333332709
Bike: @PathFollow3D@25 Finish time: 15859.4333332708
Bike: @PathFollow3D@178 Finish time: 15860.6666666042
Bike: @PathFollow3D@184 Finish time: 15860.6666666042
Bike: @PathFollow3D@76 Finish time: 15860.9333332708
Bike: @PathFollow3D@143 Finish time: 15861.6999999375
Bike: @PathFollow3D@155 Finish time: 15862.1666666041
Bike: @PathFollow3D@10 Finish time: 15862.6666666041
Bike: @PathFollow3D@17 Finish time: 15862.6666666041
Bike: @PathFollow3D@144 Finish time: 15862.6999999375
Bike: @PathFollow3D@151 Finish time: 15862.6999999375
Bike: @PathFollow3D@177 Finish time: 15862.6999999375
Bike: @PathFollow3D@150 Finish time: 15862.9999999375
Bike: @PathFollow3D@145 Finish time: 15863.2999999375
Bike: @PathFollow3D@102 Finish time: 15863.3999999375
Bike: @PathFollow3D@168 Finish time: 15863.3999999375
Bike: @PathFollow3D@161 Finish time: 15863.6999999374
sim_time=15870.0333332707 wall_time=16657.704 ratio=0.95271433165523 clusters=15
sim_time=15900.0333332703 wall_time=16687.688 ratio=0.95280025209425 clusters=15
sim_time=15930.0333332698 wall_time=16717.704 ratio=0.9528840403724 clusters=15
sim_time=15960.0333332694 wall_time=16747.655 ratio=0.95297122691322 clusters=15
Bike: @PathFollow3D@133 Finish time: 15977.3999999358
Bike: @PathFollow3D@110 Finish time: 15978.2999999358
Bike: @PathFollow3D@39 Finish time: 15978.4999999358
Bike: @PathFollow3D@183 Finish time: 15981.4999999357
Bike: @PathFollow3D@78 Finish time: 15982.2999999357
Bike: Bike Finish time: 15983.9999999357
Bike: @PathFollow3D@35 Finish time: 15984.2999999357
Bike: @PathFollow3D@137 Finish time: 15984.2999999357
Bike: @PathFollow3D@13 Finish time: 15985.7999999357
Bike: @PathFollow3D@20 Finish time: 15986.0666666023
Bike: @PathFollow3D@74 Finish time: 15986.7999999357
Bike: @PathFollow3D@128 Finish time: 15986.833333269
Bike: @PathFollow3D@138 Finish time: 15987.2999999356
Bike: @PathFollow3D@179 Finish time: 15988.3999999356
Bike: @PathFollow3D@75 Finish time: 15989.0666666023
Bike: @PathFollow3D@108 Finish time: 15989.6333332689
sim_time=15990.0333332689 wall_time=16777.625 ratio=0.9530570228664 clusters=7
Bike: @PathFollow3D@94 Finish time: 15992.2999999356
Bike: @PathFollow3D@88 Finish time: 15992.4666666022
Bike: @PathFollow3D@159 Finish time: 15994.9999999355
Bike: @PathFollow3D@77 Finish time: 15995.8333332689
Bike: @PathFollow3D@120 Finish time: 15997.2999999355
Bike: @PathFollow3D@182 Finish time: 15997.4999999355
Bike: @PathFollow3D@38 Finish time: 15997.7666666022
Bike: @PathFollow3D@30 Finish time: 15997.9999999355
Bike: @PathFollow3D@124 Finish time: 15998.2999999355
Bike: @PathFollow3D@70 Finish time: 16002.2999999354
Bike: @PathFollow3D@166 Finish time: 16002.7999999354
Bike: @PathFollow3D@118 Finish time: 16003.7999999354
Bike: @PathFollow3D@146 Finish time: 16004.9333332687
Bike: @PathFollow3D@96 Finish time: 16005.4333332687
Bike: @PathFollow3D@93 Finish time: 16005.7999999354
Bike: @PathFollow3D@112 Finish time: 16006.2999999354
Bike: @PathFollow3D@8 Finish time: 16006.466666602
Bike: @PathFollow3D@19 Finish time: 16006.466666602
Bike: @PathFollow3D@26 Finish time: 16006.466666602
Bike: @PathFollow3D@34 Finish time: 16006.466666602
Bike: @PathFollow3D@45 Finish time: 16006.466666602
Bike: @PathFollow3D@54 Finish time: 16006.466666602
Bike: @PathFollow3D@65 Finish time: 16006.466666602
Bike: @PathFollow3D@79 Finish time: 16006.466666602
Bike: @PathFollow3D@81 Finish time: 16006.466666602
Bike: @PathFollow3D@83 Finish time: 16006.466666602
Bike: @PathFollow3D@85 Finish time: 16006.466666602
Bike: @PathFollow3D@92 Finish time: 16006.466666602
Bike: @PathFollow3D@117 Finish time: 16006.466666602
Bike: @PathFollow3D@122 Finish time: 16006.466666602
Bike: @PathFollow3D@140 Finish time: 16006.466666602
Bike: @PathFollow3D@142 Finish time: 16006.466666602
Bike: @PathFollow3D@152 Finish time: 16006.466666602
Bike: @PathFollow3D@176 Finish time: 16006.466666602

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
