import re

data = """
Bike: @PathFollow3D@46 Finish time: 14852.8999999522
Bike: @PathFollow3D@82 Finish time: 14852.9333332855
Bike: @PathFollow3D@54 Finish time: 14853.4333332855
Bike: @PathFollow3D@183 Finish time: 14853.6333332855
Bike: @PathFollow3D@178 Finish time: 14854.2666666188
Bike: @PathFollow3D@20 Finish time: 14854.3999999521
Bike: @PathFollow3D@89 Finish time: 14854.3999999521
Bike: @PathFollow3D@39 Finish time: 14854.4333332855
Bike: @PathFollow3D@142 Finish time: 14854.4333332855
Bike: @PathFollow3D@100 Finish time: 14855.1333332855
Bike: @PathFollow3D@34 Finish time: 14855.3999999521
Bike: @PathFollow3D@162 Finish time: 14855.3999999521
Bike: @PathFollow3D@112 Finish time: 14855.8999999521
Bike: @PathFollow3D@79 Finish time: 14856.3999999521
Bike: @PathFollow3D@170 Finish time: 14856.8999999521
Bike: @PathFollow3D@171 Finish time: 14856.8999999521
Bike: @PathFollow3D@105 Finish time: 14857.0666666188
Bike: @PathFollow3D@29 Finish time: 14857.1333332854
Bike: @PathFollow3D@45 Finish time: 14857.2666666188
Bike: @PathFollow3D@87 Finish time: 14857.2666666188
Bike: @PathFollow3D@32 Finish time: 14857.3999999521
Bike: @PathFollow3D@110 Finish time: 14857.3999999521
Bike: @PathFollow3D@165 Finish time: 14857.3999999521
Bike: @PathFollow3D@116 Finish time: 14857.6333332854
Bike: @PathFollow3D@23 Finish time: 14857.8999999521
Bike: @PathFollow3D@164 Finish time: 14857.9333332854
Bike: @PathFollow3D@93 Finish time: 14857.9999999521
Bike: @PathFollow3D@159 Finish time: 14858.1999999521
Bike: @PathFollow3D@42 Finish time: 14858.6333332854
Bike: @PathFollow3D@75 Finish time: 14858.7333332854
Bike: @PathFollow3D@10 Finish time: 14858.8999999521
Bike: @PathFollow3D@104 Finish time: 14858.8999999521
Bike: @PathFollow3D@28 Finish time: 14858.9999999521
Bike: @PathFollow3D@182 Finish time: 14858.9999999521
Bike: @PathFollow3D@68 Finish time: 14859.3999999521
Bike: @PathFollow3D@14 Finish time: 14859.4999999521
Bike: @PathFollow3D@71 Finish time: 14859.4999999521
Bike: @PathFollow3D@177 Finish time: 14859.9999999521
Bike: @PathFollow3D@94 Finish time: 14860.1333332854
Bike: @PathFollow3D@133 Finish time: 14860.1333332854
Bike: @PathFollow3D@55 Finish time: 14860.399999952
Bike: @PathFollow3D@27 Finish time: 14860.499999952
Bike: @PathFollow3D@176 Finish time: 14860.9333332854
Bike: @PathFollow3D@24 Finish time: 14861.399999952
Bike: @PathFollow3D@86 Finish time: 14861.6666666187
Bike: @PathFollow3D@26 Finish time: 14862.1333332854
Bike: @PathFollow3D@21 Finish time: 14866.899999952
sim_time=14880.0333332851 wall_time=15076.276 ratio=0.98698334610517 drones=100
sim_time=14910.0333332847 wall_time=15106.275 ratio=0.98700926160054 drones=100
sim_time=14940.0333332842 wall_time=15136.262 ratio=0.98703585689018 drones=100
sim_time=14970.0333332838 wall_time=15166.303 ratio=0.98705883255028 drones=100
sim_time=15000.0333332833 wall_time=15196.443 ratio=0.98707528684728 drones=100
sim_time=15030.0333332829 wall_time=15226.508 ratio=0.98709653804293 drones=100
sim_time=15060.0333332825 wall_time=15256.483 ratio=0.98712352861944 drones=100
Bike: @PathFollow3D@136 Finish time: 15080.5333332822
Bike: @PathFollow3D@47 Finish time: 15080.9999999488
Bike: @PathFollow3D@125 Finish time: 15080.9999999488
Bike: @PathFollow3D@117 Finish time: 15081.1666666155
Bike: @PathFollow3D@6 Finish time: 15081.1999999488
Bike: @PathFollow3D@109 Finish time: 15081.9333332822
Bike: @PathFollow3D@157 Finish time: 15082.0333332822
Bike: @PathFollow3D@88 Finish time: 15082.2333332822
Bike: @PathFollow3D@22 Finish time: 15082.9999999488
Bike: @PathFollow3D@124 Finish time: 15082.9999999488
Bike: @PathFollow3D@123 Finish time: 15083.1999999488
Bike: @PathFollow3D@161 Finish time: 15083.2333332821
Bike: @PathFollow3D@84 Finish time: 15083.4666666155
Bike: @PathFollow3D@108 Finish time: 15083.6333332821
Bike: @PathFollow3D@63 Finish time: 15083.9666666155
Bike: @PathFollow3D@18 Finish time: 15083.9999999488
Bike: @PathFollow3D@126 Finish time: 15083.9999999488
Bike: @PathFollow3D@15 Finish time: 15084.1999999488
Bike: @PathFollow3D@62 Finish time: 15084.2666666155
Bike: @PathFollow3D@146 Finish time: 15084.4666666155
Bike: @PathFollow3D@140 Finish time: 15084.4999999488
Bike: @PathFollow3D@153 Finish time: 15084.4999999488
Bike: @PathFollow3D@167 Finish time: 15084.6666666155
Bike: @PathFollow3D@92 Finish time: 15084.7333332821
Bike: @PathFollow3D@19 Finish time: 15084.9333332821
Bike: @PathFollow3D@169 Finish time: 15084.9333332821
Bike: @PathFollow3D@144 Finish time: 15084.9666666154
Bike: @PathFollow3D@8 Finish time: 15084.9999999488
Bike: @PathFollow3D@141 Finish time: 15084.9999999488
Bike: @PathFollow3D@43 Finish time: 15085.2333332821
Bike: @PathFollow3D@151 Finish time: 15085.4666666154
Bike: @PathFollow3D@51 Finish time: 15085.4999999488
Bike: @PathFollow3D@61 Finish time: 15085.4999999488
Bike: @PathFollow3D@179 Finish time: 15085.4999999488
Bike: @PathFollow3D@132 Finish time: 15085.5333332821
Bike: @PathFollow3D@114 Finish time: 15085.6999999488
Bike: @PathFollow3D@173 Finish time: 15085.7999999488
Bike: @PathFollow3D@122 Finish time: 15085.9999999488
Bike: @PathFollow3D@160 Finish time: 15085.9999999488
Bike: @PathFollow3D@13 Finish time: 15086.2333332821
Bike: @PathFollow3D@74 Finish time: 15086.9333332821
Bike: @PathFollow3D@16 Finish time: 15086.9999999487
Bike: @PathFollow3D@73 Finish time: 15087.2666666154
Bike: @PathFollow3D@150 Finish time: 15087.4999999487
Bike: @PathFollow3D@168 Finish time: 15088.0666666154
Bike: @PathFollow3D@70 Finish time: 15088.4999999487
Bike: @PathFollow3D@155 Finish time: 15088.5333332821
Bike: @PathFollow3D@130 Finish time: 15088.7333332821
Bike: @PathFollow3D@7 Finish time: 15088.7666666154
Bike: @PathFollow3D@121 Finish time: 15088.9666666154
Bike: @PathFollow3D@115 Finish time: 15089.1999999487
Bike: @PathFollow3D@80 Finish time: 15089.633333282
sim_time=15090.033333282 wall_time=15286.9 ratio=0.98712187122844 drones=100
Bike: @PathFollow3D@102 Finish time: 15090.033333282
sim_time=15120.0333332816 wall_time=15316.902 ratio=0.98714696570374 drones=100
sim_time=15150.0333332812 wall_time=15346.917 ratio=0.98717112585421 drones=100
sim_time=15180.0333332807 wall_time=15376.916 ratio=0.98719621888295 drones=100
sim_time=15210.0333332803 wall_time=15407.251 ratio=0.98719968495874 drones=100
sim_time=15240.0333332799 wall_time=15437.245 ratio=0.98722494417105 drones=100
sim_time=15270.0333332794 wall_time=15467.266 ratio=0.98724838205274 drones=100
sim_time=15300.033333279 wall_time=15497.277 ratio=0.98727236618917 drones=100
Bike: @PathFollow3D@52 Finish time: 15312.8666666121
Bike: @PathFollow3D@66 Finish time: 15312.8666666121
Bike: @PathFollow3D@85 Finish time: 15314.3999999454
Bike: @PathFollow3D@33 Finish time: 15314.8999999454
Bike: @PathFollow3D@118 Finish time: 15314.9333332788
Bike: @PathFollow3D@72 Finish time: 15314.9666666121
Bike: @PathFollow3D@11 Finish time: 15315.3333332788
Bike: @PathFollow3D@90 Finish time: 15315.5333332788
Bike: @PathFollow3D@120 Finish time: 15315.7666666121
Bike: @PathFollow3D@97 Finish time: 15315.8666666121
Bike: @PathFollow3D@113 Finish time: 15316.0333332788
Bike: @PathFollow3D@181 Finish time: 15316.0999999454
Bike: @PathFollow3D@175 Finish time: 15316.3666666121
Bike: @PathFollow3D@17 Finish time: 15316.3999999454
Bike: @PathFollow3D@149 Finish time: 15316.4999999454
Bike: @PathFollow3D@76 Finish time: 15316.8666666121
Bike: @PathFollow3D@64 Finish time: 15316.8999999454
Bike: @PathFollow3D@101 Finish time: 15316.9666666121
Bike: @PathFollow3D@106 Finish time: 15316.9666666121
Bike: @PathFollow3D@143 Finish time: 15316.9666666121
Bike: @PathFollow3D@49 Finish time: 15317.2333332787
Bike: @PathFollow3D@138 Finish time: 15317.3666666121
Bike: @PathFollow3D@59 Finish time: 15317.4333332787
Bike: @PathFollow3D@25 Finish time: 15318.4999999454
Bike: @PathFollow3D@111 Finish time: 15318.8333332787
Bike: @PathFollow3D@36 Finish time: 15318.866666612
Bike: @PathFollow3D@9 Finish time: 15318.966666612
Bike: @PathFollow3D@154 Finish time: 15319.0999999454
Bike: @PathFollow3D@57 Finish time: 15319.366666612
Bike: @PathFollow3D@119 Finish time: 15319.5333332787
Bike: @PathFollow3D@145 Finish time: 15320.1999999454
Bike: @PathFollow3D@30 Finish time: 15320.2333332787
Bike: @PathFollow3D@172 Finish time: 15320.2333332787
Bike: @PathFollow3D@69 Finish time: 15320.466666612
Bike: @PathFollow3D@56 Finish time: 15320.566666612
Bike: @PathFollow3D@37 Finish time: 15320.866666612
Bike: @PathFollow3D@38 Finish time: 15320.9333332787
Bike: @PathFollow3D@163 Finish time: 15321.2333332787
Bike: @PathFollow3D@128 Finish time: 15321.266666612
Bike: @PathFollow3D@48 Finish time: 15321.5333332787
Bike: @PathFollow3D@131 Finish time: 15321.7333332787
Bike: @PathFollow3D@147 Finish time: 15322.1999999453
Bike: @PathFollow3D@95 Finish time: 15322.2333332787
Bike: @PathFollow3D@174 Finish time: 15324.9999999453
Bike: @PathFollow3D@31 Finish time: 15327.1666666119
sim_time=15330.0333332785 wall_time=15527.244 ratio=0.98729905534289 drones=100
sim_time=15360.0333332781 wall_time=15557.245 ratio=0.9873234838995 drones=100
sim_time=15390.0333332777 wall_time=15587.242 ratio=0.98734807179344 drones=100
sim_time=15420.0333332772 wall_time=15617.247 ratio=0.98737205944666 drones=100
sim_time=15450.0333332768 wall_time=15647.234 ratio=0.9873970909668 drones=100
sim_time=15480.0333332764 wall_time=15677.245 ratio=0.98742051510175 drones=100
sim_time=15510.0333332759 wall_time=15707.777 ratio=0.98741109790876 drones=100
sim_time=15540.0333332755 wall_time=15737.611 ratio=0.98744551083868 drones=100
Bike: @PathFollow3D@137 Finish time: 15566.4666666084
Bike: @PathFollow3D@53 Finish time: 15567.2999999418
Bike: @PathFollow3D@58 Finish time: 15567.9666666084
Bike: @PathFollow3D@81 Finish time: 15567.9666666084
Bike: @PathFollow3D@134 Finish time: 15568.0999999417
Bike: Bike Finish time: 15568.2999999417
Bike: @PathFollow3D@148 Finish time: 15568.4666666084
Bike: @PathFollow3D@91 Finish time: 15568.4999999417
Bike: @PathFollow3D@156 Finish time: 15568.9333332751
Bike: @PathFollow3D@77 Finish time: 15568.9666666084
Bike: @PathFollow3D@99 Finish time: 15568.9666666084
Bike: @PathFollow3D@166 Finish time: 15569.4666666084
Bike: @PathFollow3D@60 Finish time: 15569.8333332751
Bike: @PathFollow3D@139 Finish time: 15569.9999999417
sim_time=15570.0333332751 wall_time=15767.587 ratio=0.98747090047926 drones=100
Bike: @PathFollow3D@44 Finish time: 15570.433333275
Bike: @PathFollow3D@129 Finish time: 15570.4666666084
Bike: @PathFollow3D@41 Finish time: 15570.9666666084
Bike: @PathFollow3D@180 Finish time: 15570.9666666084
Bike: @PathFollow3D@135 Finish time: 15571.033333275
Bike: @PathFollow3D@184 Finish time: 15571.4666666084
Bike: @PathFollow3D@127 Finish time: 15571.5666666084
Bike: @PathFollow3D@158 Finish time: 15571.833333275
Bike: @PathFollow3D@12 Finish time: 15571.933333275
Bike: @PathFollow3D@35 Finish time: 15571.9666666084
Bike: @PathFollow3D@98 Finish time: 15571.9666666084
Bike: @PathFollow3D@103 Finish time: 15572.4999999417
Bike: @PathFollow3D@107 Finish time: 15573.033333275
Bike: @PathFollow3D@50 Finish time: 15573.4999999417
Bike: @PathFollow3D@67 Finish time: 15573.4999999417
Bike: @PathFollow3D@152 Finish time: 15573.4999999417
Bike: @PathFollow3D@78 Finish time: 15573.7999999417
Bike: @PathFollow3D@83 Finish time: 15573.9666666083
Bike: @PathFollow3D@40 Finish time: 15574.2666666083
Bike: @PathFollow3D@96 Finish time: 15574.4666666083
Bike: @PathFollow3D@65 Finish time: 15576.9999999416
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
