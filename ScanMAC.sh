#!/bin/bash
#============================================================================================
#        File: ScanMAC.sh
#    Function: Scan(Compare) LAN and BMC MAC address, and save in file MAC#.TXT, BMCMAC#.TXT
#     Version: 1.1.3
#      Author: Cody,qiutiqin@msi.com
#     Created: 2018-07-11
#     Updated: 2019-06-27
#  Department: Application engineering course
# 		 Note: Update for Batch test mode
# 		       Add the tool: scanner for forbidden keyboard input
#			   Add the control of range
# Environment: Linux/CentOS
#============================================================================================
#----Define sub function---------------------------------------------------------------------
echoPass()
 { 	local String=$@ 
	echo -en "\e[1;32m ${String}\e[0m"
	[ ${#String} -gt 60 ] && pnt=70 || pnt=60
	let PNT=${pnt}+10 
	echo -e "\e[${pnt}G [\e[1;32m  PASS  \e[0;39m]"
	str=$(printf "%-${PNT}s" "-") 
	echo  -e "\e[1;32m${str// /-}\e[0m"
 }
 
echoFail()
 { 	local String=$@ 
	echo -en "\e[1;31m $String\e[0m"
	[ ${#String} -gt 60 ] && pnt=70 || pnt=60
	let PNT=${pnt}+10 
	echo -e "\e[${pnt}G [\e[1;31m  FAIL  \e[0;39m]"
	str=$(printf "%-${PNT}s" "-") 
	echo  -e "\e[1;31m${str// /-}\e[0m"
	BeepRemind 1 2>/dev/null
 }

Process()
{ 	
	local Status="$1"
	local String="$2"
	case $Status in
		0)
			printf "%-3s\e[1;32m%-2s\e[0m%-5s%-60s\n" "[  " "OK" "  ]  " "${String}"
		;;

		*)
			printf "%-3s\e[1;31m%-2s\e[0m%-5s%-60s\n" "[  " "NG" "  ]  " "${String}"
			BeepRemind 1 2>/dev/null
			return 1
		;;
		esac
}

BeepRemind()
{
	local Status="$1"
	# load pc speaker driver
	lsmod | grep -iq "pcspkr" || modprobe pcspkr
	which beep >/dev/null 2>&1 || return 0

	case ${Status:-"0"} in
		0)beep -f 1800 > /dev/null 2>&1;;
		*)beep -f 800 -l 800 > /dev/null 2>&1;;
		esac
}

ChkExternalCommands ()
{
	ExtCmmds=(xmlstarlet)
	for((c=0;c<${#ExtCmmds[@]};c++))
	do
	_ExtCmmd=$(command -v ${ExtCmmds[$c]})
	if [ $? != 0 ]; then
		Process 1 "No such tool or command: ${ExtCmmds[$c]}"
		let ErrorFlag++
	else
		chmod 777 ${_ExtCmmd}
	fi
	done
	[ ${ErrorFlag} != 0 ] && exit 127
}

ShowMsg ()
{
	local LineId=$1
	local TextMsg=${@:2:70}
	TextMsg=${TextMsg:0:60}

	echo $LineId | grep -iEq  "[1-9BbEe]"
	if [ $? -ne 0 ] ; then
		echo " Usage: ShowMsg --[n|[B|b][E|e]] TextMessage"
		echo "        n=1,2,3,...,9"
		exit 3
	fi

	#---> Show Message
	case $LineId in
		--1)	
			printf "\e[0;30;43m%-72s\e[0m\n" " ********************************************************************** "
			printf "\e[0;30;43m%-6s%-60s%6s\e[0m\n" " **"  "${TextMsg}"  "** "
			printf "\e[0;30;43m%-72s\e[0m\n" " ********************************************************************** "
		;;

		--[Bb])
			printf "\e[0;30;43m%-72s\e[0m\n" " ********************************************************************** "
			printf "\e[0;30;43m%-6s%-60s%6s\e[0m\n" " **"  "${TextMsg}"  "** "
		;;
		
		--[2-9])
			printf "\e[0;30;43m%-6s%-60s%6s\e[0m\n" " **"  "${TextMsg}"  "** "
		;;
		
		--[Ee])
			printf "\e[0;30;43m%-6s%-60s%6s\e[0m\n" " **"  "${TextMsg}"  "** "
			printf "\e[0;30;43m%-72s\e[0m\n" " ********************************************************************** "
		;;
		esac
}

PrintfTipYellow()
{
	local String="$@"
	LCutCnt=$(echo "ibase=10;obase=10; (70-${#String})/2" | bc)
	RCutCnt=$(echo "ibase=10;obase=10; 50-${LCutCnt}" | bc)
	Left=$(echo "<<------------------------------------------------" | cut -c 1-${LCutCnt})
	Right=$(echo "------------------------------------------------>>" | cut -c ${RCutCnt}-)
	local PrintfStr="${Left}${String}${Right}"
	printf "\e[0;30;43m%70s\e[0m\n" "${PrintfStr}"
}

PrintfTipBlue()
{
	local String="$@"
	LCutCnt=$(echo "ibase=10;obase=10; (70-${#String})/2" | bc)
	RCutCnt=$(echo "ibase=10;obase=10; 50-${LCutCnt}" | bc)
	Left=$(echo "<<------------------------------------------------" | cut -c 1-${LCutCnt})
	Right=$(echo "------------------------------------------------>>" | cut -c ${RCutCnt}-)
	local PrintfStr="${Left}${String}${Right}"
	printf "\e[0;30;44m%70s\e[0m\n" "${PrintfStr}"
}

#--->Show the usage
Usage ()
{
cat <<HELP | more
Usage: 
`basename $0` [-x lConfig.xml] [-D]
	eg.: `basename $0` -x lConfig.xml
	eg.: `basename $0` -D
		 
	-D : Dump the sample xml config file
	-x : config file,format as: *.xml

	return code:
		0 : Scan MAC address pass
		1 : Scan MAC address fail
		2 : File is not exist
		3 : Parameters error
	    Other : Failure
HELP
exit 3
}

DumpXML()
{
	cat <<-Sample | xmlstarlet fo | tee ${BaseName}.xml
	<Scan>
		<TestCase>
			<ProgramName>${BaseName}</ProgramName>
			
			<!-- ScanMAC.sh: LAN 和BMC MAC的掃描程式 -->
			<!--可以用於批量測試，設置不同的ProgramName="ScanMAC"即可,例如S1401+S140A-->
			<!-- Compare: enable表示掃描后再次掃描首尾MAC比對; disable：僅掃描一次，不做比對 -->
			<Compare>enable</Compare>
			<SavePath>/TestAP/Scan</SavePath>
			
			<!-- ProgramName="ScanMAC" 對應的程式是: ScanMAC.sh -->
			<!-- BMC2LAN is the relation between BMC MAC and LAN MAC -->
			<!-- GT: BMC MAC great than LAN MACs-->
			<!-- LT: BMC MAC less than LAN MACs -->
			<!-- NA: BMC MAC not the same as LAN MACs-->
			<BMC2LAN>NA</BMC2LAN>
			
			<WhichModel>S1401</WhichModel>	
			
			<LAN>
				<!--MAC的數量,沒有則填0-->
				<Amount>4</Amount>
				<!--起始號，默認1，即MAC1.txt-->
				<StartNumber>1</StartNumber>
				<!-- Define the first MAC address is  ODD (1), Even (0), Un-limit(U) --> 
				<FirstMAC>ODD</FirstMAC>
				<!--  First 6 digits of MAC address. If is 'FFFFFF', ignore to check. -->
				<First6Bit>FFFFFF</First6Bit>
				
				<!--范圍控制,無需控制範圍則置空,格式是 309C82000000-309C82FFFFFF-->
				<Range></Range>
			</LAN>

			<BMC>
				<!--BMC MAC的數量,沒有則填0-->
				<Amount>1</Amount>
				<!--起始號，默認1，即BMCMAC1.txt-->
				<StartNumber>1</StartNumber>
				<!-- Define the first MAC address is  ODD (1), Even (0), Un-limit(U) --> 
				<FirstMAC>U</FirstMAC>
				<!--  First 6 digits of MAC address. If is 'FFFFFF', ignore to check. -->
				<First6Bit>FFFFFF</First6Bit>
				
				<!--范圍控制,無需控制範圍則置空,格式是 309C82000000-309C82FFFFFF-->
				<Range></Range>
			</BMC>
		</TestCase>
	</Scan>
	Sample
	sync;sync;sync

	xmlstarlet val "${BaseName}.xml" >/dev/null 2>&1
	if [ $? != 0 ] ; then
		Process 1 "Invalid XML file: ${BaseName}.xml"
		xmlstarlet fo ${BaseName}.xml
		exit 3
	else
		Process 0 "Created the XML file: ${BaseName}.xml"
		exit 0
	fi
}

#--->Get the parameters from the config file
GetParametersFrXML  ()
{
	xmlstarlet val "${XmlConfigFile}" >/dev/null 2>&1
	if [ $? != 0 ] ; then
		xmlstarlet fo ${XmlConfigFile}
		Process 1 "Invalid XML file: ${XmlConfigFile}"
		exit 3
	fi  
	
	xmlstarlet sel -t -v "//ProgramName" -n "${XmlConfigFile}" 2>/dev/null | grep -iwq "${BaseName}"
	if [ $? != 0 ] ; then
		Process 1 "Thers's no configuration information for ${BaseName}.sh"
		exit 3
	fi
	
	# Get the information from the config file
	Compare=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/Compare" -n "${XmlConfigFile}" 2>/dev/null)
	SavePath=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/SavePath" -n "${XmlConfigFile}" 2>/dev/null)

	BMC2LAN=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/BMC2LAN" -n "${XmlConfigFile}" 2>/dev/null)
	WhichModel=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/WhichModel" -n "${XmlConfigFile}" 2>/dev/null)

	LanAmount=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/LAN/Amount" -n "${XmlConfigFile}" 2>/dev/null)
	BmcAmount=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/BMC/Amount" -n "${XmlConfigFile}" 2>/dev/null)

	LanStartNumber=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/LAN/StartNumber" -n "${XmlConfigFile}" 2>/dev/null)
	BmcStartNumber=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/BMC/StartNumber" -n "${XmlConfigFile}" 2>/dev/null)
	LanStartNumber=${LanStartNumber:-"1"}
	BmcStartNumber=${BmcStartNumber:-"1"}

	LanFirstMAC=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/LAN/FirstMAC" -n "${XmlConfigFile}" 2>/dev/null)
	BmcFirstMAC=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/BMC/FirstMAC" -n "${XmlConfigFile}" 2>/dev/null)

	LanFirst6Bit=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/LAN/First6Bit" -n "${XmlConfigFile}" 2>/dev/null)
	BmcFirst6Bit=$(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/BMC/First6Bit" -n "${XmlConfigFile}" 2>/dev/null)

	LanMacAddrRange=($(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/LAN/Range" -n "${XmlConfigFile}" 2>/dev/null))
	BmcMacAddrRange=($(xmlstarlet sel -t -v "//Scan/TestCase[ProgramName=\"${BaseName}\"]/BMC/Range" -n "${XmlConfigFile}" 2>/dev/null))

	if [ ${#SavePath} == 0 ] ; then
		Process 1 "Error config file: ${XmlConfigFile}"
		exit 3
	fi
	return 0
}

# Usage MacAddrRangeContrl MACAddr
MacAddrRangeContrl()
{
	local TargetMac=$1
	local TargetType=$2
	local SubErrorFlag=0

	case ${TargetType} in 
		BMC)MacAddrRange=($(echo ${BmcMacAddrRange[@]}));;
		LAN)MacAddrRange=($(echo ${LanMacAddrRange[@]}));;
		esac	

	for ((r=0;r<${#MacAddrRange[@]};r++))
	do
		LowerLimitTmp=$(echo ${MacAddrRange[$r]} | awk -F'-' '{print $1}')
		UpperLimitTmp=$(echo ${MacAddrRange[$r]} | awk -F'-' '{print $2}')

		if [ ${#LowerLimitTmp} == 0 ] || [ ${#UpperLimitTmp} == 0 ] ; then
			continue
		fi
		
		flag=$(echo "ibase=16;obase=16;${LowerLimitTmp}>=${UpperLimitTmp}" | bc )
		if [ ${flag} == 0 ] ; then
			LowerLimit=${LowerLimitTmp}
			UpperLimit=${UpperLimitTmp}
		else
			LowerLimit=${UpperLimitTmp}
			UpperLimit=${LowerLimitTmp}
		fi

		GreatFlag=$(echo "ibase=16;obase=10;${TargetMac}>=${LowerLimit}" | bc)
		LessFlag=$(echo "ibase=16;obase=10;${TargetMac}<=${UpperLimit}" | bc)
		let flag=${GreatFlag}+${LessFlag}
		if [ ${flag} != 2 ] ; then
			let SubErrorFlag++
		else
			SubErrorFlag=0
			break
		fi
	done

	if [ ${SubErrorFlag} -ne 0 ] ; then
		Process 1 "${TargetMac} is out of range"
		
		printf "\e[1m%-4s%-18s%-18s%-18s%-12s\n\e[0m" " No " "    LowerLimit    " "    UpperLimit    " "    CurrentMAC    " "   Result? "
		echo -e "----------------------------------------------------------------------"
		for ((r=0;r<${#MacAddrRange[@]};r++))
		do
			let R=$r+1
			if [ $r -le 9 ] ; then
				R="0${R}"
			fi
			
			LowerLimitTmp=$(echo ${MacAddrRange[$r]} | awk -F'-' '{print $1}')
			UpperLimitTmp=$(echo ${MacAddrRange[$r]} | awk -F'-' '{print $2}')

			flag=$(echo "ibase=16;obase=16;${LowerLimitTmp}>=${UpperLimitTmp}" | bc )
			if [ ${flag} == 0 ] ; then
				LowerLimit=${LowerLimitTmp}
				UpperLimit=${UpperLimitTmp}
			else
				LowerLimit=${UpperLimitTmp}
				UpperLimit=${LowerLimitTmp}
			fi
			
			printf "%-4s%-18s%-18s%-18s\e[1;31m%-12s\n\e[0m" " $R " "   ${LowerLimit}   " "   ${UpperLimit}   " "   ${TargetMac}   " "  OutOfRange"
			
		done
		echo -e "----------------------------------------------------------------------"
		
		return 1
	fi
}

# Usage: MacAddrRuleContrl 309C12341234 1 ODD FFFFFF 
MacAddrRuleContrl()
{
	local TargetMac=$1
	local OrdinalNumber=$2
	local OddOrEven=$(echo $3 | tr [a-z] [A-Z])
	local TargetFirst6Bit=$(echo $4 | tr [a-z] [A-Z])
	local SubErrorFlag=0
	# Check the mac first 6bit
	if [ $(echo "${LanFirst6Bit}" | grep -ic 'FFFFFF' ) == 0 ] ; then
		if [ $(echo ${TargetMac} | cut -c 1-6 | grep -ic "${LanFirst6Bit}") != 1 ] ; then		
			Process 1 "Check the first 6bit of ${TargetMac}"
			printf "%-10s%-60s\n" "" "Current first 6bit is: `echo ${TargetMac} | cut -c 1-6`"
			printf "%-10s%-60s\n" "" " First 6bit should be: ${LanFirst6Bit}"
			let SubErrorFlag++
		fi
	fi


	#Check ODD/Even/Un-limit
	if [ $OrdinalNumber == ${StartNumber} ] ; then
		GetOddEven=$(echo "ibase=16; ${TargetMac}%2" | bc )
		case ${OddOrEven} in
		ODD|1)
			if [ ${GetOddEven} != "1" ] ; then
				Process 1 "Check Odd or Even of first MAC address: ${TargetMac}"
				printf "%-10s%-60s\n" "" "The last byte of current MAC is: ${TargetMac:11} (Even)"
				printf "%-10s%-60s\n" "" " The last byte of MAC should be: 1/3/5/7/9/B/D/F (Odd)"
				let SubErrorFlag++			
			fi
		;;
		
		EVEN|0)
			if [ ${GetOddEven} != "0" ] ; then
				Process 1 "Check Odd or Even of first MAC address: ${TargetMac}"
				printf "%-10s%-60s\n" "" "The last byte of current MAC is: ${TargetMac:11} (Odd)"
				printf "%-10s%-60s\n" "" " The last byte of MAC should be: 0/2/4/6/8/A/C/E (Even)"
				let SubErrorFlag++			
			fi
		;;
		
		*)
			:
		;;
		esac
	fi

	if [ $SubErrorFlag != 0 ] ; then
		return 1
	else
		return 0
	fi
}

#RemoveMacFile MAC|BMCMAC StartNumber MacAmount
RemoveMacFile()
{
	local FileType=$1
	local Start=$2
	local Amount=$3
	for ((R=${StartNumber};R<${StartNumber}+${MacAmount};R++))
	do
		rm -rf ${FileType}${R}.TXT 2>/dev/null
		rm -rf ${FileType}${R}.txt 2>/dev/null
	done
	}

	# Usage ScanMACAddress BMC|LAN 5 6
	ScanMACAddress()
	{
	local MacType=$(echo $1 | tr [a-z] [A-Z])
	local MacAmount=$(echo $2 | tr -d '[[:alpha:]][[:punct:]]')
	local StartNumber=$(echo $3 | tr -d '[[:alpha:]][[:punct:]]')
	local ModelType=$(echo $4 | tr '[a-z]' '[A-Z]')

	local CurMac=()
	local NextMac='0'
	[ ! -d "${SavePath}" ] && mkdir -p ${SavePath} 2>/dev/null

	if [ ${MacType} == 'LAN' ] ; then
		local FirstMAC="$LanFirstMAC"
		local First6Bit="$LanFirst6Bit"
		local SaveFile='MAC'
	else
		local FirstMAC="$BmcFirstMAC"
		local First6Bit="$BmcFirst6Bit"
		local SaveFile='BMCMAC'
	fi

	RemoveMacFile "${SaveFile}" "${StartNumber}" "${MacAmount}"

	echo -e "\n\e[1mThere are $MacAmount PCs ${MacType} MAC address barcode(s) of ${ModelType} will be scaned ...\e[0m\n"

	#for((i=1;i<=${MacAmount};i++))
	for((i=${StartNumber};i<${MacAmount}+${StartNumber};i++))
	do
		# OP can try Chance times while scan a mac fail
		Chance=3
		
		while :
		do
			if [ $Chance -lt 0 ] ; then
				echo "Too many failures, exiting ... "
				RemoveMacFile "${SaveFile}" "${StartNumber}" "${MacAmount}"
				exit 1
			fi
			
			BeepRemind 0		
			PrintfTipYellow "Please scan the 12-bit ${MacType}$(($i-${StartNumber}+1)) MAC address, eg.: 309C23BA3162"
			echo -ne "Scan \e[5;32m ${MacType}$(($i-${StartNumber}+1))\e[0m of \e[1;31m${ModelType}\e[0m MAC Address: ____________\b\b\b\b\b\b\b\b\b\b\b\b" 
			which scanner >/dev/null 2>&1
			if [ $? == 0 ] ; then
				#rm -rf ${WorkPath}/scan_${BaseName}.txt >/dev/null 2>&1
				#scanner ${WorkPath}/scan_${BaseName}.txt || continue
				#read mac<${WorkPath}/scan_${BaseName}.txt
				#rm -rf ${WorkPath}/scan_${BaseName}.txt >/dev/null 2>&1
			#else
				read mac
			fi	
			
			echo
			CurMac[$i]=$(echo $mac | tr [a-z] [A-Z] | grep -v "309C23BA3162" | grep -E '^[0-9A-F]{12}+$')
			if [ "${#CurMac[$i]}" == "0" ]; then
				Process 1 "Invalid ${MacType} MAC address: $mac `[ ${#mac} != 12 ] && echo "(${#mac} Bit)"`"
				InvalidChar=$(echo $mac | tr -d [a-fA-F0-9])
				[ ${#InvalidChar} != 0 ] && echo -e "Current ${MacType} MAC address include invalid chars: \e[1;31m${InvalidChar}\e[0m"
				printf "%-10s%-60s\n" "" "Try again ..."
				echo
				let Chance--
				continue 
			else
				# Check the MACs are consecutive numbers
				if [ ${i} -gt ${StartNumber} ] && [ "$NextMac"x != "${CurMac[$i]}"x ] ; then
					Process 1 "${CurMac[i-1]} and ${CurMac[$i]} are not consecutive numbers"
					echo
					let Chance--
					continue
				fi
			
				# Check ODD, and firs 6 byte
				# Usage: MacAddrRuleContrl 309C12341234 1 ODD FFFFFF 
				MacAddrRuleContrl ${CurMac[$i]} $i $FirstMAC $First6Bit
				if [ $? == 0 ] ; then
					DoubleFile=($(find ${SavePath} -type f -iname "*.txt" -print | sort -u | grep -i "MAC" | grep -iv "${SaveFile}${i}.TXT" | xargs md5sum 2>/dev/null | grep -iw `echo ${CurMac[$i]} | md5sum | awk '{print $1}'` | awk '{print $2}'))
					if [ ${#DoubleFile[@]} != 0 ] ; then
						Process 1 "Double files are found. Scan fail."
						printf "%30s%-13s\n" "Current scan in is: " "${CurMac[$i]}"
						for((V=0;V<${#DoubleFile[@]};V++))
						do
							printf "%30s%-13s\n" "${DoubleFile[$V]}: " "${CurMac[$i]}"
						done
						let Chance--					
						continue
					fi
				
					echo ${CurMac[$i]} > ${SavePath}/${SaveFile}${i}.TXT
					sync;sync;sync
					if [ $(cat "${SavePath}/${SaveFile}${i}.TXT" 2>/dev/null | grep -iEc "[0-9A-F]{${#mac}}") != 1 ]; then
						Process 1 "Invalid MAC file(0KB): ${SavePath}/${SaveFile}${i}.TXT"
						echo
						let Chance--
						continue
					fi
					
					if [ ${MacType} == 'BMC' ] && [ $Product != 0 ] ; then
						#for((L=1;L<=${LanAmount};L++))
						for((L=${LanStartNumber};L<${LanAmount}+${LanStartNumber};L++))
						do
							TempMacAddr=$(cat ${SavePath}/MAC${L}.TXT  2>/dev/null )
							DiffMac=$(echo ${TempMacAddr} | grep -i "${CurMac[$i]}" )
							if [ ${#DiffMac} != 0 ]	; then
								Process 1 "Found BMC and LAN MAC address files are same. Check MAC"
								echo "${CurMac[$i]} is the same as: ${SavePath}/MAC${L}.TXT(${TempMacAddr}) "
								echo
								let Chance--
								continue 2
							fi
						
							Gap=$(echo "obase=10; ibase=16; ${CurMac[$i]}-${TempMacAddr}" | bc |tr -d ' ')
							case ${BMC2LAN} in
								[Gg][Tt])
									if [ $Gap -le 0 ]; then
										Process 1 "BMCMAC(${CurMac[$i]}) is less than LAN MAC(${TempMacAddr})"
										echo
										let Chance--
										continue 2
									fi
								;;
								
								[Ll][Tt])
									if [ $Gap -ge 0 ]; then
										Process 1 "BMCMAC(${CurMac[$i]}) is great than LAN MAC(${TempMacAddr})"
										echo
										let let Chance--
										continue 2
									fi
								;;
								
								*)
									:	
								;;
								esac	
						done
					fi
					
					# Check the MAC address range
					MacAddrRangeContrl ${CurMac[$i]} ${MacType}
					if [ $? != 0 ] ; then
						echo
						let Chance--
						continue
					fi
					
					# Scan current mac ok, break out
					break
				else
					echo
					let Chance--
					continue
				fi
			fi
			
		done

		NextMac=$(echo "obase=16; ibase=16; ${CurMac[$i]}+1 " | bc | tr '[a-f]' '[A-F]' |tr -d ' ')
		NextMac=$(printf "%012X" "0x${NextMac}")
	done
}

# Usage ScanMACAddress BMC|LAN 5 4
CompareMACAddress()
{
	local MacType=$(echo $1 | tr [a-z] [A-Z])
	local MacAmount=$(echo $2 | tr -d '[[:alpha:]][[:punct:]]')
	local StartNumber=$(echo $3 | tr -d '[[:alpha:]][[:punct:]]')
	local ModelType=$(echo $4 | tr '[a-z]' '[A-Z]')
	local CurMac=()
	local NextMac='0'

	# MacAmount is a decimal number, convert to Hexadecimal(MacAmount2Hex)
	MacAmount2Hex=$(echo "obase=16; ibase=10; ${MacAmount}" | bc | tr '[a-f]' '[A-F]' |tr -d ' ')

	[ ! -d "${SavePath}" ] && mkdir -p ${SavePath} 2>/dev/null

	if [ ${MacType} == 'LAN' ] ; then
		local FirstMAC="$LanFirstMAC"
		local First6Bit="$LanFirst6Bit"
		local SaveFile='MAC'
	else
		local FirstMAC="$BmcFirstMAC"
		local First6Bit="$BmcFirst6Bit"
		local SaveFile='BMCMAC'
	fi

	#for((i=1;i<=${MacAmount};i++))
	for((i=${StartNumber};i<${MacAmount}+${StartNumber};i++))
	do
		# OP can try Chance times while scan a mac fail
		Chance=3
		
		while :
		do
			if [ $Chance -lt 0 ] ; then
				echo "Too many failures, exiting ... "
				RemoveMacFile "${SaveFile}" "${StartNumber}" "${MacAmount}"
				exit 1
			fi
			
			if [ ${#NextMac} == 0 ] || [ ${i} == ${StartNumber} ] ; then 
				BeepRemind 0
				PrintfTipBlue "Please scan the 12-bit ${MacType}$(($i-${StartNumber}+1)) MAC address, eg.: 309C23BA3162"
				echo -ne "Scan \e[5;32m ${MacType}$(($i-${StartNumber}+1))\e[0m of \e[1;31m${ModelType}\e[0m MAC Address: ____________\b\b\b\b\b\b\b\b\b\b\b\b"
				which scanner >/dev/null 2>&1
				if [ $? == 0 ] ; then
					#rm -rf ${WorkPath}/scan_${BaseName}.txt >/dev/null 2>&1
					#scanner ${WorkPath}/scan_${BaseName}.txt || continue
					#read mac<${WorkPath}/scan_${BaseName}.txt
					#rm -rf ${WorkPath}/scan_${BaseName}.txt >/dev/null 2>&1
				#else
					read mac
				fi				
			else
				BeepRemind 0
				PrintfTipBlue "Please scan the 12-bit last ${MacType} MAC address, eg.: 309C23BA3162"
				echo -ne "Scan the \e[5;32mlast ${MacType}\e[0m of \e[1;31m${ModelType}\e[0m MAC Address: ____________\b\b\b\b\b\b\b\b\b\b\b\b"
				which scanner >/dev/null 2>&1
				if [ $? == 0 ] ; then
					#rm -rf ${WorkPath}/scan_${BaseName}.txt >/dev/null 2>&1
					#scanner ${WorkPath}/scan_${BaseName}.txt || continue
					#read mac<${WorkPath}/scan_${BaseName}.txt
					#rm -rf ${WorkPath}/scan_${BaseName}.txt >/dev/null 2>&1
				#else
					read mac
				fi			
			fi
			
			echo
			CurMac[$i]=$(echo $mac | tr [a-z] [A-Z] | grep -v "309C23BA3162" | grep -E '^[0-9A-F]{12}+$')
			if [ "${#CurMac[$i]}" == "0" ]; then
				Process 1 "Invalid MAC address: $mac `[ ${#mac} != 12 ] && echo "(${#mac} Bit)"`"
				InvalidChar=$(echo $mac | tr -d [a-fA-F0-9])
				[ ${#InvalidChar} != 0 ] && echo -e "Current ${MacType} MAC address include invalid chars: \e[1;31m${InvalidChar}\e[0m"
				printf "%-10s%-60s\n" "" "Try again ..."
				echo
				let Chance--
				continue 
			else
				# Check the MACs are consecutive numbers
				if [ ${i} -gt ${StartNumber} ] ; then
					if [ "$NextMac"x != "${CurMac[$i]}"x ] && [ "${CurMac[$i]}"x != "${LastMac}"x ] ; then
						Process 1 "${CurMac[i-1]} and ${CurMac[$i]} are not consecutive numbers"
						echo
						let Chance--
						continue
					fi
				fi
			
			
				# Check ODD, and firs 6 byte
				# Usage: MacAddrRuleContrl 309C12341234 1 ODD FFFFFF 
				MacAddrRuleContrl ${CurMac[$i]} $i $FirstMAC $First6Bit
				
				# Compare then 2nd scan with the 1st scan
				if [ $? == 0 ] ; then
					if [ "${CurMac[$i]}"x == "${LastMac}"x ]; then
					
						# Auto compare 
						for((s=${StartNumber};s<${MacAmount}+${StartNumber};s++))
						do
							s2Hex=$(echo "obase=16; ibase=10; ${s}-${StartNumber}+1" | bc | tr '[a-f]' '[A-F]' |tr -d ' ')
							TempMac=$(echo "obase=16; ibase=16; ${CurMac[${StartNumber}]}+${s2Hex}-1" | bc | tr '[a-f]' '[A-F]' |tr -d ' ')
							TempMac=$(printf "%012X" "0x${TempMac}")
							cat -v ${SavePath}/${SaveFile}${s}.TXT  2>/dev/null | grep -iwq ${TempMac}
							if [ $? != 0 ] ; then
								Process 1 "The 1st and 2nd scan MACs are not the same MAC. Compare"
								printf "%-10s%-60s\n" "" "       2nd scan MAC address is: ${TempMac}"
								printf "%-10s%-60s\n" "" "1st scan MAC address should be: `cat ${SavePath}/${SaveFile}${s}.TXT 2>/dev/null `(${SavePath}/${SaveFile}${s}.TXT)"
								let ErrorFlag++
							fi
						done
						
					else
						# Compare one by one
						cat -v ${SavePath}/${SaveFile}${i}.TXT  2>/dev/null  | grep -iwq ${CurMac[$i]}
						if [ $? != 0 ] ; then
							Process 1 "The 1st and 2nd scan MACs are not the same MAC, Compare"
							printf "%-10s%-60s\n" "" "       2nd scan MAC address is: ${CurMac[$i]}"
							printf "%-10s%-60s\n" "" "1st scan MAC address should be: `cat ${SavePath}/${SaveFile}${i}.TXT  2>/dev/null `(${SavePath}/${SaveFile}${i}.TXT)"
							let ErrorFlag++
						else
							ErrorFlag=0
						fi
						
					fi
					
					if [ ${ErrorFlag} != 0 ] ; then
						echo
						let Chance--
						continue
					else
					
						if [ ${MacType} == 'BMC' ] && [ $Product != 0 ] ; then
							for((L=${LanStartNumber};L<${LanAmount}+${LanStartNumber};L++))
							do
								TempMacAddr=$(cat ${SavePath}/MAC${L}.TXT 2>/dev/null )
								DiffMac=$(echo ${TempMacAddr} | grep -i "${CurMac[$i]}" )
								if [ ${#DiffMac} != 0 ]	; then
									Process 1 "Found BMC and LAN MAC address files are same. Check MAC"
									printf "%-10s%-60s\n" "" "${CurMac[$i]} is the same as: ${SavePath}/MAC${L}.TXT(${TempMacAddr}) "
									echo
									let Chance--
									continue 2
								fi
								
								Gap=$(echo "obase=10; ibase=16; ${CurMac[$i]}-${TempMacAddr}" | bc |tr -d ' ')
								case ${BMC2LAN} in
									[Gg][Tt])
										if [ $Gap -le 0 ]; then
											Process 1 "BMCMAC(${CurMac[$i]}) is less than LAN MAC(${TempMacAddr})"
											echo
											let Chance--
											continue 2
										fi
									;;
									
									[Ll][Tt])
										if [ $Gap -ge 0 ]; then
											Process 1 "BMCMAC(${CurMac[$i]}) is great than LAN MAC(${TempMacAddr})"
											echo
											let let Chance--
											continue 2
										fi
									;;
									
									*)
										:	
									;;
									esac
							done
						fi
						
						# Scan current mac ok, break out
						break
					fi
				
				else
					echo
					let Chance--
					continue
				fi
			fi
			
		done
		
		if [ "${CurMac[$i]}"x == "${NextMac}"x ] ; then
			echo -e "\e[33m${CurMac[$i]} is the ${MacType}$i MAC address ...\e[0m\n"
		fi
		
		if [ "${CurMac[$i]}"x == "${LastMac}"x ] ; then
			echo -e "${CurMac[$i]} is the last ${MacType} MAC address ..."
			echo -e "\e[32mThe 2nd scan ${MacType} MAC address finish ...\e[0m\n"
			break
		fi
		
		NextMac=$(echo "obase=16; ibase=16; ${CurMac[$i]}+1" | bc | tr '[a-f]' '[A-F]' |tr -d ' ')
		LastMac=$(echo "obase=16; ibase=16; ${CurMac[${StartNumber}]}+${MacAmount2Hex}-1" | bc | tr '[a-f]' '[A-F]' |tr -d ' ')
		NextMac=$(printf "%012X" "0x${NextMac}")
		LastMac=$(printf "%012X" "0x${LastMac}")
	done
}

main ()
{
	which scanner >/dev/null 2>&1
	if [ $? != 0 ] && [ -f "scanner" ] ; then
		chmod 777 ./scanner >/dev/null 2>&1
		cp -rf ./scanner /bin >/dev/null 2>&1	 
	fi

	LanAmount=$(echo $LanAmount | tr -d '[[:alpha:]][[:punct:]]')
	BmcAmount=$(echo $BmcAmount | tr -d '[[:alpha:]][[:punct:]]')
	LanAmount=${LanAmount:-'0'}
	BmcAmount=${BmcAmount:-'0'}

	SavePath=${SavePath:-"${WorkPath}"}

	LanStartNumber=${LanStartNumber:-"1"}
	BmcStartNumber=${BmcStartNumber:-"1"}

	let Product=${LanAmount}*${BmcAmount}
	let Summary=${LanAmount}+${BmcAmount}

	EOS=$(echo $SavePath | tr -d ' ' | awk -F'/' '{print $NF}')
	if [ ${#EOS} == 0 ] ; then
		let CutLength=${#SavePath}-1
		SavePath=$(echo $SavePath | tr -d ' ' | cut -c 1-${CutLength} )
	else
		SavePath=$(echo $SavePath | tr -d ' ')
	fi

	WhichModel=${WhichModel:-"Current MODEL"}
	ShowMsg --b "Scan MAC address bar codes from small to large."
	ShowMsg --2 "Only the scanner can be used to scan MAC barcodes."
	ShowMsg --e "No keyboard input MAC address bar code is allowed."

	# 1st scan, record the scan result
	if [ "$LanAmount"x != "0"x ] ; then
		ScanMACAddress "LAN" "$LanAmount" "${LanStartNumber}" "${WhichModel}"
	fi

	if [ "$BmcAmount"x != "0"x ] ; then
		ScanMACAddress "BMC" "$BmcAmount" "${BmcStartNumber}" "${WhichModel}"
	fi

	# 2nd scan, double check
	if [ ${Summary} -gt 2 ] && [ "${Compare}"x == 'enable'x ] ; then
		echo -e "\e[0;30;44m ********************************************************************* \e[0m"
		echo -e "\e[0;30;44m **        Scan the first and the last MAC address bar codes.       ** \e[0m"
		echo -e "\e[0;30;44m **        Only the scanner can be used to scan MAC barcodes.       ** \e[0m"
		echo -e "\e[0;30;44m **        No keyboard input MAC address bar code is allowed.       ** \e[0m"
		echo -e "\e[0;30;44m ********************************************************************* \e[0m"
		echo
	fi

	if [ "$LanAmount"x != "0"x ] && [ "${Compare}x" == 'enable'x ] ; then
		CompareMACAddress "LAN" "$LanAmount" "${LanStartNumber}" "${WhichModel}"
	fi

	if [ "$BmcAmount"x != "0"x ] && [ "${Compare}x" == 'enable'x ] ; then
		CompareMACAddress "BMC" "$BmcAmount" "${BmcStartNumber}" "${WhichModel}"
	fi

	# Print the scan file
	echo
	let F=1
	echo -e "\e[1m Search the test record and clear the files ... \e[0m"
	printf "\e[1m%-4s%-30s%-6s%-16s%-6s%-7s\n\e[0m" " No " " Path of MAC File" "" "  MACs Address  " ""  "LAN/BMC"
	echo -e "======================================================================"
	for((L=${LanStartNumber};L<${LanAmount}+${LanStartNumber};L++))
	do
		F=$(printf "%02d" ${F})
		printf "%-4s%-30s%-6s%-16s%-7s\e[1;32m%-5s\n\e[0m" " $F " "${WorkPath}/MAC${L}.TXT" "" "  `cat ${WorkPath}/MAC${L}.TXT 2>/dev/null | head -n1`  "  ""  " LAN " 
		F=$(echo "ibase=10;obase=10; ${F}+1" | bc)
	done

	echo -e "----------------------------------------------------------------------"

	for((B=${BmcStartNumber};B<${BmcAmount}+${BmcStartNumber};B++))
	do
		F=$(printf "%02d" ${F})
		printf "%-4s%-30s%-6s%-16s%-7s\e[1;34m%-5s\n\e[0m" " $F " "${WorkPath}/BMCMAC${B}.TXT" "" "  `cat ${WorkPath}/BMCMAC${B}.TXT 2>/dev/null | head -n1`  "  ""  " BMC " 
		F=$(echo "ibase=10;obase=10; ${F}+1" | bc)
	done
	echo -e "======================================================================"

	if [ $ErrorFlag != 0 ] ; then
		echoFail "Scan LAN or BMC MAC address"
		exit 1
	else
		echoPass "Scan LAN or BMC MAC address"
	fi
}
#----main function-----------------------------------------------------------------------------
declare WorkPath=$(cd `dirname $0`; pwd)
declare ShellFile=$(basename $0)
declare BaseName=$(basename $0 .sh)
declare UtilityPath=$(cd `dirname $0`; cd ../utility 2>/dev/null; pwd)
declare -i ErrorFlag=0
declare Compare='disable'
declare XmlConfigFile SavePath BMC2LAN LanStartNumber BmcStartNumber 
declare LanAmount BmcAmount LanFirstMAC BmcFirstMAC LanFirst6Bit BmcFirst6Bit WhichModel
# Define the Mac address range
declare -a MacAddrRange=()
declare -a LanMacAddrRange=()
declare -a BmcMacAddrRange=()

#Change the directory
cd ${WorkPath} >/dev/null 2>&1 
declare PATH=${PATH}:${UtilityPath}:`pwd`

if [ $# -lt 1 ] ; then
	Usage 
fi
ChkExternalCommands

#--->Get and process the parameters
while getopts :Dx: argv
do
	case ${argv} in
		x)
			XmlConfigFile=${OPTARG}
			GetParametersFrXML
			break
		;;

		D)
			DumpXML
			break
		;;

		:)
			printf "\e[1;33m%-s\n\e[0m" "The option ${OPTARG} requires an argument."
			Usage
			exit 3
		;;
		
		?)
			printf "\e[1;33m%-s\n\n\e[0m" "Invalid option: ${OPTARG}"
			Usage
			exit 3			
		;;
		esac

done
	
main
[ ${ErrorFlag} != 0 ] && exit 1
exit 0
