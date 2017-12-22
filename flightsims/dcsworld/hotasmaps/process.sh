#!/bin/bash

echo "#!/bin/bash" > generator.sh
echo "convert template.png \\" >> generator.sh

if [ "$1" == "" ]; then
	BUTTONS="buttons.txt"
else
	BUTTONS="$1"
fi

while read -u 4 line; do
	PARAM=`echo "$line" | awk -F, '{print $1}'`
	OFFSET=`echo "$line" | awk -F, '{print $2}'`
	SIZE=`echo "$line" | awk -F, '{print $3}'`
	FILL=`echo "$line" | awk -F, '{print $4}'`

	TEXT=`grep -i "^$PARAM\\s" "$BUTTONS" | cut -f2-`
	
	if [ "$TEXT" != "" ]; then
		echo "$PARAM"
		echo "    -background none -fill $FILL -size $SIZE -gravity center caption:\"$TEXT\" -gravity northwest -geometry $OFFSET -compose over -composite \\" >> ./generator.sh
	fi
done 4<<- EOF
	TITLE,+5+5,380x110,blue
	JS_POV1_UP,+531+46,98x32,blue
	JS_POV1_DOWN,+531+182,98x32,blue
	JS_POV1_LEFT,+419+113,98x32,blue
	JS_POV1_RIGHT,+637+113,98x32,blue
	JS_MMCB,+565+256,98x32,blue
	JS_PICKLE,+123+154,98x32,blue
	JS_TMS_UP,+108+229,98x32,blue
	JS_TMS_DOWN,+108+325,98x32,blue
	JS_TMS_LEFT,+24+276,98x32,blue
	JS_TMS_RIGHT,+190+276,98x32,blue
	JS_CMS_FORE,+108+482,98x32,blue
	JS_CMS_AFT,+33+578,98x32,blue
	JS_CMS_LEFT,+24+529,98x32,blue
	JS_CMS_RIGHT,+192+529,98x32,blue
	JS_CMS_PRESS,+146+584,98x32,blue
	JS_DMS_UP,+547+337,98x32,blue
	JS_DMS_DOWN,+547+432,98x32,blue
	JS_DMS_LEFT,+463+383,98x32,blue
	JS_DMS_RIGHT,+630+383,98x32,blue
	JS_TRIGGER1,+333+806,98x32,blue
	JS_TRIGGER2,+356+866,98x32,blue
	JS_NSB,+621+864,98x32,blue
	JS_LEVER,+606+919,98x32,blue
	JS_PITCH,+110+645,98x32,blue
	JS_ROLL,+195+754,98x32,blue
	ENGFUEL_LEFT,+1054+27,82x25,blue
	ENGFUEL_RIGHT,+1159+27,82x25,blue
	ENGOP_L_UP,+1375+159,82x25,blue
	ENGOP_L_DOWN,+1375+185,82x25,blue
	ENGOP_R_UP,+1375+213,82x25,blue
	ENGOP_R_DOWN,+1375+240,82x25,blue
	APUSTART,+1326+270,82x25,blue
	SLIDER0,+1384+317,82x25,blue
	LGSILENCE,+1371+362,82x25,blue
	FLAPSUP,+847+339,82x25,blue
	FLAPSDOWN,+847+364,82x25,blue
	EACARM,+831+480,82x25,blue
	RDRALTM_NRM,+913+568,82x25,blue
	AUTOPILOT,+1234+568,82x25,blue
	AUTOPILOT_UP,+1383+454,82x25,blue
	AUTOPILOT_DOWN,+1383+479,82x25,blue
	POV2_UP,+1007+607,82x25,blue
	POV2_DOWN,+1007+710,82x25,blue
	POV2_LEFT,+927+658,82x25,blue
	POV2_RIGHT,+1089+658,82x25,blue
	SLEW_PRESS,+1196+725,82x25,blue
	SLEW_AXIS,+1274+641,82x25,blue
	LEFTBUTTON,+1379+703,82x25,blue
	PINKY_FWD,+1400+878,82x25,blue
	PINKY_AFT,+1400+907,82x25,blue
	MIC_UP,+858+723,82x25,blue
	MIC_DOWN,+810+785,82x25,blue
	MIC_FWD,+912+754,82x25,blue
	MIC_AFT,+804+754,82x25,blue
	MIC_PRESS,+882+788,82x25,blue
	BRAKE_FWD,+858+812,82x25,blue
	BRAKE_AFT,+858+834,82x25,blue
	BOAT_FWD,+858+858,82x25,blue
	BOAT_AFT,+858+880,82x25,blue
	CHINA_FWD,+858+904,82x25,blue
	CHINA_AFT,+858+926,82x25,blue
EOF

echo "    output.jpg" >> generator.sh
chmod a+x generator.sh
./generator.sh
rm generator.sh
