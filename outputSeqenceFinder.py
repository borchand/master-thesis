import re

data = """
Godot Engine v4.6.2.stable.mono.official.71f334935 - https://godotengine.org
OpenGL API 3.3.0 NVIDIA 560.94 - Compatibility - Using Device: NVIDIA - NVIDIA GeForce RTX 2060

Bike: @PathFollow3D@167 Finish time: 15276.1499998619  Watts: 391 Maxspeed: 22.4264688416107 Process_counter: 916569 Controller_counter: 61104
Bike: @PathFollow3D@73 Finish time: 15276.2499998619  Watts: 391 Maxspeed: 22.3746450700614 Process_counter: 916575 Controller_counter: 61104
Bike: @PathFollow3D@75 Finish time: 15276.2499998619  Watts: 391 Maxspeed: 22.3746450700614 Process_counter: 916575 Controller_counter: 61104
Bike: @PathFollow3D@164 Finish time: 15276.3666665285  Watts: 391 Maxspeed: 23.123153955716 Process_counter: 916582 Controller_counter: 61105
Bike: @PathFollow3D@28 Finish time: 15276.3833331952  Watts: 391 Maxspeed: 22.9170092969001 Process_counter: 916583 Controller_counter: 61105
Bike: @PathFollow3D@24 Finish time: 15276.5166665285  Watts: 391 Maxspeed: 22.2704476988398 Process_counter: 916591 Controller_counter: 61106
Bike: @PathFollow3D@144 Finish time: 15276.6333331952  Watts: 391 Maxspeed: 22.4944139490071 Process_counter: 916598 Controller_counter: 61106
Bike: @PathFollow3D@76 Finish time: 15276.7333331952  Watts: 391 Maxspeed: 21.7999937109445 Process_counter: 916604 Controller_counter: 61106
Bike: @PathFollow3D@86 Finish time: 15276.7333331952  Watts: 391 Maxspeed: 23.0256836551524 Process_counter: 916604 Controller_counter: 61106
Bike: @PathFollow3D@6 Finish time: 15276.7499998618  Watts: 391 Maxspeed: 22.509364121172 Process_counter: 916605 Controller_counter: 61106
Bike: @PathFollow3D@63 Finish time: 15276.7499998618  Watts: 391 Maxspeed: 22.5137140581871 Process_counter: 916605 Controller_counter: 61106
Bike: @PathFollow3D@154 Finish time: 15276.7499998618  Watts: 391 Maxspeed: 22.6839336025066 Process_counter: 916605 Controller_counter: 61106
Bike: @PathFollow3D@170 Finish time: 15276.7666665285  Watts: 391 Maxspeed: 22.9336680555074 Process_counter: 916606 Controller_counter: 61107
Bike: @PathFollow3D@34 Finish time: 15276.8333331952  Watts: 391 Maxspeed: 22.4618064134513 Process_counter: 916610 Controller_counter: 61107
Bike: @PathFollow3D@27 Finish time: 15276.8833331952  Watts: 391 Maxspeed: 22.5585920194985 Process_counter: 916613 Controller_counter: 61107
Bike: @PathFollow3D@151 Finish time: 15276.8833331952  Watts: 391 Maxspeed: 22.4394474460143 Process_counter: 916613 Controller_counter: 61107
Bike: @PathFollow3D@25 Finish time: 15276.9499998618  Watts: 391 Maxspeed: 23.0609162414397 Process_counter: 916617 Controller_counter: 61107
Bike: @PathFollow3D@79 Finish time: 15276.9666665285  Watts: 391 Maxspeed: 22.0492321489615 Process_counter: 916618 Controller_counter: 61107
Bike: @PathFollow3D@40 Finish time: 15276.9999998618  Watts: 391 Maxspeed: 23.1103238163244 Process_counter: 916620 Controller_counter: 61107
Bike: @PathFollow3D@183 Finish time: 15276.9999998618  Watts: 391 Maxspeed: 22.0136990414833 Process_counter: 916620 Controller_counter: 61107
Bike: @PathFollow3D@33 Finish time: 15277.1333331952  Watts: 391 Maxspeed: 23.1656335025808 Process_counter: 916628 Controller_counter: 61108
Bike: @PathFollow3D@97 Finish time: 15277.1333331952  Watts: 391 Maxspeed: 22.6219187366469 Process_counter: 916628 Controller_counter: 61108
Bike: @PathFollow3D@119 Finish time: 15277.1333331952  Watts: 391 Maxspeed: 22.5578745381534 Process_counter: 916628 Controller_counter: 61108
Bike: @PathFollow3D@174 Finish time: 15277.1499998618  Watts: 391 Maxspeed: 22.0977862289111 Process_counter: 916629 Controller_counter: 61108
Bike: @PathFollow3D@168 Finish time: 15277.2666665285  Watts: 391 Maxspeed: 21.8194256085403 Process_counter: 916636 Controller_counter: 61109
Bike: @PathFollow3D@78 Finish time: 15277.2833331952  Watts: 391 Maxspeed: 23.065657157453 Process_counter: 916637 Controller_counter: 61109
Bike: @PathFollow3D@54 Finish time: 15277.4166665285  Watts: 391 Maxspeed: 21.5602537215804 Process_counter: 916645 Controller_counter: 61109
Bike: @PathFollow3D@159 Finish time: 15277.4499998618  Watts: 391 Maxspeed: 23.1717215360635 Process_counter: 916647 Controller_counter: 61109
Bike: @PathFollow3D@131 Finish time: 15277.4833331952  Watts: 391 Maxspeed: 21.3850478201177 Process_counter: 916649 Controller_counter: 61109
Bike: @PathFollow3D@82 Finish time: 15277.4999998618  Watts: 391 Maxspeed: 23.272754239951 Process_counter: 916650 Controller_counter: 61109
Bike: @PathFollow3D@64 Finish time: 15277.5166665285  Watts: 391 Maxspeed: 21.8640543893332 Process_counter: 916651 Controller_counter: 61110
Bike: @PathFollow3D@112 Finish time: 15277.5666665285  Watts: 391 Maxspeed: 22.1297393665101 Process_counter: 916654 Controller_counter: 61110
Bike: @PathFollow3D@47 Finish time: 15277.6499998618  Watts: 391 Maxspeed: 22.9116531850738 Process_counter: 916659 Controller_counter: 61110
Bike: @PathFollow3D@182 Finish time: 15277.6499998618  Watts: 391 Maxspeed: 23.123387540304 Process_counter: 916659 Controller_counter: 61110
Bike: @PathFollow3D@7 Finish time: 15277.7499998618  Watts: 391 Maxspeed: 22.940761548502 Process_counter: 916665 Controller_counter: 61110
Bike: @PathFollow3D@104 Finish time: 15277.7499998618  Watts: 391 Maxspeed: 21.9806761999572 Process_counter: 916665 Controller_counter: 61110
Bike: @PathFollow3D@18 Finish time: 15277.8833331952  Watts: 391 Maxspeed: 21.7796749983886 Process_counter: 916673 Controller_counter: 61111
Bike: @PathFollow3D@110 Finish time: 15277.8833331952  Watts: 391 Maxspeed: 21.7796749983886 Process_counter: 916673 Controller_counter: 61111
Bike: @PathFollow3D@14 Finish time: 15277.8999998618  Watts: 391 Maxspeed: 21.8506569917237 Process_counter: 916674 Controller_counter: 61111
Bike: @PathFollow3D@58 Finish time: 15277.8999998618  Watts: 391 Maxspeed: 23.1416358764417 Process_counter: 916674 Controller_counter: 61111
Bike: @PathFollow3D@30 Finish time: 15277.9166665285  Watts: 391 Maxspeed: 21.9756095483068 Process_counter: 916675 Controller_counter: 61111
Bike: @PathFollow3D@60 Finish time: 15277.9999998618  Watts: 391 Maxspeed: 22.5365348408085 Process_counter: 916680 Controller_counter: 61111
Bike: @PathFollow3D@114 Finish time: 15278.0499998618  Watts: 391 Maxspeed: 23.2435364167503 Process_counter: 916683 Controller_counter: 61112
Bike: @PathFollow3D@145 Finish time: 15278.0499998618  Watts: 391 Maxspeed: 21.5962102798072 Process_counter: 916683 Controller_counter: 61112
Bike: @PathFollow3D@138 Finish time: 15278.0666665285  Watts: 391 Maxspeed: 23.04320507674 Process_counter: 916684 Controller_counter: 61112
Bike: @PathFollow3D@31 Finish time: 15278.1499998618  Watts: 391 Maxspeed: 22.4412680872347 Process_counter: 916689 Controller_counter: 61112
Bike: @PathFollow3D@125 Finish time: 15278.1499998618  Watts: 391 Maxspeed: 23.2448854022569 Process_counter: 916689 Controller_counter: 61112
Bike: @PathFollow3D@55 Finish time: 15293.8666665283  Watts: 382 Maxspeed: 22.2658853392792 Process_counter: 917632 Controller_counter: 61175
Bike: @PathFollow3D@103 Finish time: 15294.1333331949  Watts: 382 Maxspeed: 22.4999003156269 Process_counter: 917648 Controller_counter: 61176
Bike: @PathFollow3D@142 Finish time: 15294.1499998616  Watts: 382 Maxspeed: 21.8091445776808 Process_counter: 917649 Controller_counter: 61176
Bike: @PathFollow3D@177 Finish time: 15294.1499998616  Watts: 382 Maxspeed: 22.7710136526971 Process_counter: 917649 Controller_counter: 61176
Bike: @PathFollow3D@57 Finish time: 15294.1666665283  Watts: 382 Maxspeed: 22.5591081824608 Process_counter: 917650 Controller_counter: 61176
Bike: @PathFollow3D@84 Finish time: 15294.1999998616  Watts: 382 Maxspeed: 22.5782080863256 Process_counter: 917652 Controller_counter: 61176
Bike: @PathFollow3D@99 Finish time: 15294.3666665283  Watts: 382 Maxspeed: 22.6474741373812 Process_counter: 917662 Controller_counter: 61177
Bike: @PathFollow3D@180 Finish time: 15294.3999998616  Watts: 382 Maxspeed: 23.0654115015064 Process_counter: 917664 Controller_counter: 61177
Bike: @PathFollow3D@23 Finish time: 15294.4166665283  Watts: 382 Maxspeed: 21.9047128729084 Process_counter: 917665 Controller_counter: 61177
Bike: @PathFollow3D@52 Finish time: 15294.6333331949  Watts: 382 Maxspeed: 22.318677420784 Process_counter: 917678 Controller_counter: 61178
Bike: @PathFollow3D@42 Finish time: 15294.6666665282  Watts: 382 Maxspeed: 22.4250242034761 Process_counter: 917680 Controller_counter: 61178
Bike: @PathFollow3D@53 Finish time: 15294.6666665282  Watts: 382 Maxspeed: 22.836941949434 Process_counter: 917680 Controller_counter: 61178
Bike: @PathFollow3D@67 Finish time: 15294.8833331949  Watts: 382 Maxspeed: 22.3981145555198 Process_counter: 917693 Controller_counter: 61179
Bike: @PathFollow3D@41 Finish time: 15294.8999998616  Watts: 382 Maxspeed: 22.5337491316186 Process_counter: 917694 Controller_counter: 61179
Bike: @PathFollow3D@94 Finish time: 15294.9166665282  Watts: 382 Maxspeed: 22.2937242381725 Process_counter: 917695 Controller_counter: 61179
Bike: @PathFollow3D@106 Finish time: 15294.9166665282  Watts: 382 Maxspeed: 22.3973255058824 Process_counter: 917695 Controller_counter: 61179
Bike: @PathFollow3D@26 Finish time: 15295.1166665282  Watts: 382 Maxspeed: 22.4899297931424 Process_counter: 917707 Controller_counter: 61180
Bike: @PathFollow3D@111 Finish time: 15295.3999998616  Watts: 382 Maxspeed: 22.6027472902309 Process_counter: 917724 Controller_counter: 61181
Bike: Bike Finish time: 15295.4166665282  Watts: 382 Maxspeed: 22.5975338471714 Process_counter: 917725 Controller_counter: 61181
Bike: @PathFollow3D@50 Finish time: 15295.6333331949  Watts: 382 Maxspeed: 22.4281233004045 Process_counter: 917738 Controller_counter: 61182
Bike: @PathFollow3D@8 Finish time: 15295.8833331949  Watts: 382 Maxspeed: 21.6828813697089 Process_counter: 917753 Controller_counter: 61183
Bike: @PathFollow3D@115 Finish time: 15295.8833331949  Watts: 382 Maxspeed: 22.8128809478461 Process_counter: 917753 Controller_counter: 61183
Bike: @PathFollow3D@132 Finish time: 15295.8999998616  Watts: 382 Maxspeed: 22.693682485929 Process_counter: 917754 Controller_counter: 61183
Bike: @PathFollow3D@72 Finish time: 15296.1333331949  Watts: 382 Maxspeed: 23.1082495132048 Process_counter: 917768 Controller_counter: 61184
Bike: @PathFollow3D@184 Finish time: 15296.3166665282  Watts: 382 Maxspeed: 22.5958195226997 Process_counter: 917779 Controller_counter: 61185
Bike: @PathFollow3D@46 Finish time: 15296.7333331949  Watts: 373 Maxspeed: 22.712537083813 Process_counter: 917804 Controller_counter: 61186
Bike: @PathFollow3D@149 Finish time: 15296.9833331949  Watts: 373 Maxspeed: 22.3598955154117 Process_counter: 917819 Controller_counter: 61187
Bike: @PathFollow3D@56 Finish time: 15339.6333331943  Watts: 391 Maxspeed: 22.0612726348114 Process_counter: 920378 Controller_counter: 61358
Bike: @PathFollow3D@100 Finish time: 15356.883333194  Watts: 382 Maxspeed: 21.7922687356112 Process_counter: 921413 Controller_counter: 61427
Bike: @PathFollow3D@65 Finish time: 15357.133333194  Watts: 382 Maxspeed: 22.5372000615228 Process_counter: 921428 Controller_counter: 61428
Bike: @PathFollow3D@35 Finish time: 15357.1666665273  Watts: 382 Maxspeed: 21.9010870640195 Process_counter: 921430 Controller_counter: 61428
Bike: @PathFollow3D@37 Finish time: 15357.3666665273  Watts: 382 Maxspeed: 22.6804712694119 Process_counter: 921442 Controller_counter: 61429
Bike: @PathFollow3D@36 Finish time: 15357.383333194  Watts: 382 Maxspeed: 22.5972393958641 Process_counter: 921443 Controller_counter: 61429
Bike: @PathFollow3D@29 Finish time: 15357.4166665273  Watts: 382 Maxspeed: 22.7811347968468 Process_counter: 921445 Controller_counter: 61429
Bike: @PathFollow3D@176 Finish time: 15357.6499998607  Watts: 382 Maxspeed: 22.8615707164541 Process_counter: 921459 Controller_counter: 61430
Bike: @PathFollow3D@48 Finish time: 15357.6666665273  Watts: 382 Maxspeed: 22.132479844823 Process_counter: 921460 Controller_counter: 61430
Bike: @PathFollow3D@162 Finish time: 15357.983333194  Watts: 373 Maxspeed: 22.7418458648272 Process_counter: 921479 Controller_counter: 61431
Bike: @PathFollow3D@135 Finish time: 15358.083333194  Watts: 373 Maxspeed: 22.1966046737379 Process_counter: 921485 Controller_counter: 61432
Bike: @PathFollow3D@32 Finish time: 15358.233333194  Watts: 373 Maxspeed: 22.4238996932102 Process_counter: 921494 Controller_counter: 61432
Bike: @PathFollow3D@153 Finish time: 15358.233333194  Watts: 373 Maxspeed: 22.3598955154117 Process_counter: 921494 Controller_counter: 61432
Bike: @PathFollow3D@16 Finish time: 15358.2499998607  Watts: 373 Maxspeed: 22.3699202407745 Process_counter: 921495 Controller_counter: 61432
Bike: @PathFollow3D@59 Finish time: 15358.2666665273  Watts: 373 Maxspeed: 22.4844224390219 Process_counter: 921496 Controller_counter: 61433
Bike: @PathFollow3D@83 Finish time: 15358.3666665273  Watts: 373 Maxspeed: 22.6540858314525 Process_counter: 921502 Controller_counter: 61433
Bike: @PathFollow3D@128 Finish time: 15358.483333194  Watts: 373 Maxspeed: 22.6510199390755 Process_counter: 921509 Controller_counter: 61433
Bike: @PathFollow3D@62 Finish time: 15358.533333194  Watts: 373 Maxspeed: 22.1583487270662 Process_counter: 921512 Controller_counter: 61434
Bike: @PathFollow3D@108 Finish time: 15361.9166665273  Watts: 364 Maxspeed: 22.4025904050976 Process_counter: 921715 Controller_counter: 61447
Bike: @PathFollow3D@49 Finish time: 15380.4333331937  Watts: 391 Maxspeed: 21.6109555341154 Process_counter: 922826 Controller_counter: 61521
Bike: @PathFollow3D@148 Finish time: 15380.466666527  Watts: 391 Maxspeed: 21.2093357173415 Process_counter: 922828 Controller_counter: 61521
Bike: @PathFollow3D@152 Finish time: 15380.666666527  Watts: 391 Maxspeed: 21.1855360519495 Process_counter: 922840 Controller_counter: 61522
Bike: @PathFollow3D@88 Finish time: 15396.3666665268  Watts: 382 Maxspeed: 21.0874561919622 Process_counter: 923782 Controller_counter: 61585
Bike: @PathFollow3D@45 Finish time: 15396.3833331934  Watts: 382 Maxspeed: 21.8750781880266 Process_counter: 923783 Controller_counter: 61585
Bike: @PathFollow3D@81 Finish time: 15396.6333331934  Watts: 382 Maxspeed: 22.2048313435877 Process_counter: 923798 Controller_counter: 61586
Bike: @PathFollow3D@13 Finish time: 15396.6499998601  Watts: 382 Maxspeed: 22.2771920531086 Process_counter: 923799 Controller_counter: 61586
Bike: @PathFollow3D@95 Finish time: 15396.6499998601  Watts: 382 Maxspeed: 21.1499007693661 Process_counter: 923799 Controller_counter: 61586
Bike: @PathFollow3D@101 Finish time: 15396.6499998601  Watts: 382 Maxspeed: 23.0545714755713 Process_counter: 923799 Controller_counter: 61586
Bike: @PathFollow3D@122 Finish time: 15396.9166665268  Watts: 382 Maxspeed: 21.7179887082097 Process_counter: 923815 Controller_counter: 61587
Bike: @PathFollow3D@15 Finish time: 15396.9833331934  Watts: 373 Maxspeed: 22.0597385062152 Process_counter: 923819 Controller_counter: 61587
Bike: @PathFollow3D@44 Finish time: 15396.9833331934  Watts: 373 Maxspeed: 22.3649760772914 Process_counter: 923819 Controller_counter: 61587
Bike: @PathFollow3D@90 Finish time: 15396.9833331934  Watts: 373 Maxspeed: 21.5085822546879 Process_counter: 923819 Controller_counter: 61587
Bike: @PathFollow3D@147 Finish time: 15397.4833331934  Watts: 373 Maxspeed: 22.5311014244669 Process_counter: 923849 Controller_counter: 61589
Bike: @PathFollow3D@61 Finish time: 15397.7333331934  Watts: 373 Maxspeed: 22.1947977843933 Process_counter: 923864 Controller_counter: 61590
Bike: @PathFollow3D@158 Finish time: 15397.7333331934  Watts: 373 Maxspeed: 21.4660650225821 Process_counter: 923864 Controller_counter: 61590
Bike: @PathFollow3D@22 Finish time: 15399.2333331934  Watts: 373 Maxspeed: 22.9275518332862 Process_counter: 923954 Controller_counter: 61596
Bike: @PathFollow3D@157 Finish time: 15438.6666665262  Watts: 382 Maxspeed: 22.4062246288354 Process_counter: 926320 Controller_counter: 61754
Bike: @PathFollow3D@80 Finish time: 15438.7333331928  Watts: 373 Maxspeed: 21.3906759132691 Process_counter: 926324 Controller_counter: 61754
Bike: @PathFollow3D@130 Finish time: 15438.8833331928  Watts: 382 Maxspeed: 22.5317392211139 Process_counter: 926333 Controller_counter: 61755
Bike: @PathFollow3D@39 Finish time: 15438.9666665261  Watts: 373 Maxspeed: 21.9401864895273 Process_counter: 926338 Controller_counter: 61755
Bike: @PathFollow3D@117 Finish time: 15438.9666665261  Watts: 373 Maxspeed: 21.1086900725836 Process_counter: 926338 Controller_counter: 61755
Bike: @PathFollow3D@105 Finish time: 15439.1999998595  Watts: 373 Maxspeed: 21.1312257131242 Process_counter: 926352 Controller_counter: 61756
Bike: @PathFollow3D@169 Finish time: 15439.1999998595  Watts: 373 Maxspeed: 22.8240396722452 Process_counter: 926352 Controller_counter: 61756
Bike: @PathFollow3D@69 Finish time: 15439.2333331928  Watts: 373 Maxspeed: 20.9883842773732 Process_counter: 926354 Controller_counter: 61756
Bike: @PathFollow3D@93 Finish time: 15439.4666665261  Watts: 373 Maxspeed: 21.0265501900252 Process_counter: 926368 Controller_counter: 61757
Bike: @PathFollow3D@165 Finish time: 15439.4833331928  Watts: 373 Maxspeed: 21.0211494934542 Process_counter: 926369 Controller_counter: 61757
Bike: @PathFollow3D@91 Finish time: 15439.4999998595  Watts: 373 Maxspeed: 22.1960261473764 Process_counter: 926370 Controller_counter: 61757
Bike: @PathFollow3D@129 Finish time: 15439.4999998595  Watts: 373 Maxspeed: 21.5046239467047 Process_counter: 926370 Controller_counter: 61757
Bike: @PathFollow3D@77 Finish time: 15439.9666665261  Watts: 373 Maxspeed: 22.4838454213546 Process_counter: 926398 Controller_counter: 61759
Bike: @PathFollow3D@74 Finish time: 15439.9833331928  Watts: 373 Maxspeed: 21.6079869141364 Process_counter: 926399 Controller_counter: 61759
Bike: @PathFollow3D@120 Finish time: 15439.9833331928  Watts: 373 Maxspeed: 21.0678846784227 Process_counter: 926399 Controller_counter: 61759
Bike: @PathFollow3D@51 Finish time: 15442.5499998594  Watts: 364 Maxspeed: 21.6331665101992 Process_counter: 926553 Controller_counter: 61770
Bike: @PathFollow3D@179 Finish time: 15442.8999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926574 Controller_counter: 61771
Bike: @PathFollow3D@87 Finish time: 15443.0166665261  Watts: 364 Maxspeed: 21.9741217113105 Process_counter: 926581 Controller_counter: 61772
Bike: @PathFollow3D@171 Finish time: 15443.0166665261  Watts: 364 Maxspeed: 22.1334734795782 Process_counter: 926581 Controller_counter: 61772
Bike: @PathFollow3D@121 Finish time: 15443.1666665261  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926590 Controller_counter: 61772
Bike: @PathFollow3D@66 Finish time: 15443.2333331928  Watts: 364 Maxspeed: 21.5406276381049 Process_counter: 926594 Controller_counter: 61772
Bike: @PathFollow3D@173 Finish time: 15443.2333331928  Watts: 364 Maxspeed: 21.6565859237446 Process_counter: 926594 Controller_counter: 61772
Bike: @PathFollow3D@38 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@70 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@71 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@85 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@92 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@98 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@102 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@116 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@126 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@140 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@141 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@150 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@160 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@163 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@166 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@178 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 22.0247225184711 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@181 Finish time: 15443.3999998594  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926604 Controller_counter: 61773
Bike: @PathFollow3D@136 Finish time: 15443.4333331928  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926606 Controller_counter: 61773
Bike: @PathFollow3D@107 Finish time: 15443.6666665261  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926620 Controller_counter: 61774
Bike: @PathFollow3D@133 Finish time: 15443.6666665261  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 926620 Controller_counter: 61774
Bike: @PathFollow3D@19 Finish time: 15443.8499998594  Watts: 364 Maxspeed: 21.9906682346037 Process_counter: 926631 Controller_counter: 61775
Bike: @PathFollow3D@11 Finish time: 15487.1333331921  Watts: 373 Maxspeed: 20.9294700203717 Process_counter: 929228 Controller_counter: 61948
Bike: @PathFollow3D@156 Finish time: 15500.7333331919  Watts: 373 Maxspeed: 23.0892025127073 Process_counter: 930044 Controller_counter: 62002
Bike: @PathFollow3D@10 Finish time: 15569.9999998576  Watts: 373 Maxspeed: 21.994165757658 Process_counter: 934200 Controller_counter: 62279
Bike: @PathFollow3D@17 Finish time: 15574.9833331908  Watts: 373 Maxspeed: 22.499530158561 Process_counter: 934499 Controller_counter: 62299
Bike: @PathFollow3D@161 Finish time: 15625.4999998568  Watts: 373 Maxspeed: 21.4313211003569 Process_counter: 937530 Controller_counter: 62501
Bike: @PathFollow3D@43 Finish time: 15628.4333331901  Watts: 364 Maxspeed: 21.2971653842404 Process_counter: 937706 Controller_counter: 62513
Bike: @PathFollow3D@118 Finish time: 15628.6499998567  Watts: 364 Maxspeed: 20.6731867322781 Process_counter: 937719 Controller_counter: 62514
Bike: @PathFollow3D@137 Finish time: 15628.8499998567  Watts: 364 Maxspeed: 20.4828358353062 Process_counter: 937731 Controller_counter: 62515
Bike: @PathFollow3D@172 Finish time: 15666.3666665228  Watts: 364 Maxspeed: 20.5471233294846 Process_counter: 939982 Controller_counter: 62665
Bike: @PathFollow3D@12 Finish time: 15666.9166665228  Watts: 364 Maxspeed: 20.5471233294846 Process_counter: 940015 Controller_counter: 62667
Bike: @PathFollow3D@127 Finish time: 15670.0666665228  Watts: 382 Maxspeed: 21.4489746962121 Process_counter: 940204 Controller_counter: 62680
Bike: @PathFollow3D@20 Finish time: 15670.1499998561  Watts: 382 Maxspeed: 21.3066815371808 Process_counter: 940209 Controller_counter: 62680
Bike: @PathFollow3D@143 Finish time: 15670.3833331894  Watts: 382 Maxspeed: 21.2634858922885 Process_counter: 940223 Controller_counter: 62681
Bike: @PathFollow3D@139 Finish time: 15670.3999998561  Watts: 382 Maxspeed: 20.9606934349605 Process_counter: 940224 Controller_counter: 62681
Bike: @PathFollow3D@155 Finish time: 15670.6333331894  Watts: 382 Maxspeed: 21.312339780481 Process_counter: 940238 Controller_counter: 62682
Bike: @PathFollow3D@123 Finish time: 15670.8666665228  Watts: 373 Maxspeed: 21.3416686515945 Process_counter: 940252 Controller_counter: 62683
Bike: @PathFollow3D@89 Finish time: 15670.9166665228  Watts: 373 Maxspeed: 21.294441212401 Process_counter: 940255 Controller_counter: 62683
Bike: @PathFollow3D@21 Finish time: 15670.9666665228  Watts: 373 Maxspeed: 21.1246550841742 Process_counter: 940258 Controller_counter: 62683
Bike: @PathFollow3D@96 Finish time: 15670.9666665228  Watts: 373 Maxspeed: 20.9986657779632 Process_counter: 940258 Controller_counter: 62683
Bike: @PathFollow3D@9 Finish time: 15670.9833331894  Watts: 373 Maxspeed: 21.5168555092957 Process_counter: 940259 Controller_counter: 62683
Bike: @PathFollow3D@146 Finish time: 15670.9999998561  Watts: 373 Maxspeed: 20.8432002971785 Process_counter: 940260 Controller_counter: 62683
Bike: @PathFollow3D@113 Finish time: 15671.2499998561  Watts: 373 Maxspeed: 21.1330419863557 Process_counter: 940275 Controller_counter: 62684
Bike: @PathFollow3D@109 Finish time: 15671.4833331894  Watts: 373 Maxspeed: 21.262955690568 Process_counter: 940289 Controller_counter: 62685
Bike: @PathFollow3D@68 Finish time: 15674.849999856  Watts: 364 Maxspeed: 20.5471233294846 Process_counter: 940491 Controller_counter: 62699
Bike: @PathFollow3D@175 Finish time: 15830.8833331871  Watts: 382 Maxspeed: 20.6559372022602 Process_counter: 949853 Controller_counter: 63323
Bike: @PathFollow3D@134 Finish time: 15832.1999998538  Watts: 373 Maxspeed: 20.480140938723 Process_counter: 949932 Controller_counter: 63328
Bike: @PathFollow3D@124 Finish time: 15835.8166665204  Watts: 364 Maxspeed: 20.7732755427668 Process_counter: 950149 Controller_counter: 63343
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
