' Nagios check for HWiNFO Data
'
' Code written by James Young, coding.zencoffee.org
'
' This is supplied without any warranty, express or implied.  Use at your own risk.
' My apologies for the coding travesty, VBScript is not my strongest language.


' Required Variables
Const PROGNAME = "check_hwinfo"
Const VERSION = "0.0.1"
Const HKEY_USERS = &H80000003
Const REG_SZ = 1


' Some default settings used in the Nagios plugin API
value = 0
threshold_warning = 0
threshold_critical = 0
return_code = 0
message = "All sensors within bounds"
perfdata = ""
alias = "default"

' Create the NagiosPlugin object and set it up
Set np = New NagiosPlugin
np.add_arg "sid", "SID for HWiNFO Data", 0
np.add_arg "sensor", "Sensors to check", 0
np.add_arg "warn", "Warning threshold", 0
np.add_arg "crit", "Critical threshold", 0
np.add_arg "alias", "Alias", 0

If Args.Count < 4 Or Args.Exists("help") Or np.parse_args = 0 Then
	WScript.Echo Args.Count
	np.Usage
End If

' Process arguments
sid = ""
sensor_string = ""
warn_string = ""
crit_string = ""
If Args.Exists("alias") Then alias = Args("alias")
If Args.Exists("sid") Then sid = Args("sid")
If Args.Exists("sensor") Then sensor_string = Args("sensor")
If Args.Exists("warn") Then warn_string = Args("warn")
If Args.Exists("crit") Then crit_string = Args("crit")

' Split the arguments up into data arrays
arrSensorArgs = Split(sensor_string,",")
arrWarnArgs = Split(warn_string,",")
arrCritArgs = Split(crit_string,",")

' Data testing.  Same number of arguments required for sensor, warn, and crit
if ubound(arrSensorArgs) <> ubound(arrWarnArgs) Or ubound(arrSensorArgs) <> ubound(arrCritArgs) then
	np.nagios_exit "Invalid arguments (counts must match)", 3
End If

' Fetch value out of registry
Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
oReg.EnumValues HKEY_USERS, sid & "\Software\HWiNFO64\VSB", arrValueNames, arrTypes

if Not IsArray(arrValueNames) Then
	np.nagios_exit "SID is invalid or HWiNFO64 gadget mode disabled", 3
End If

' Walk over every sensor requested
for j = LBound(arrSensorArgs) to UBound(arrSensorArgs)
	labelFound = 0

	' Try and find the HWiNFO64 sensor matching that value
	for i = LBound(arrValueNames) to UBound(arrValueNames)
		if arrTypes(i) = REG_SZ and InStr(arrValueNames(i),"Label") <> 0 then
			oReg.GetStringValue HKEY_USERS, sid & "\Software\HWiNFO64\VSB", arrValueNames(i), strLabelName

			' HWiNFO64 sensor found matching the requested value
			if InStr(strLabelName, arrSensorArgs(j)) then
				labelFound = 1
				valueString = Replace(arrValueNames(i), "Label", "")
				sensorIndex = CInt(valueString)

				' Sensor index fetched.  Now grab the value
				oReg.GetStringValue HKEY_USERS, sid & "\Software\HWiNFO64\VSB", "Value" & sensorIndex, strValue
				strValueArray = Split(strValue)
				value = CDbl(strValueArray(0))

				' Test the threshold
				threshold_warning = arrWarnArgs(j)
				threshold_critical = arrCritArgs(j)
				tempcode = np.check_threshold(value)

				' Update the return code
				if tempcode > return_code then
					if tempcode = 1 then message = "Sensor " & arrSensorArgs(j) & " in warning state!"
					if tempcode = 2 then message = "Sensor " & arrSensorArgs(j) & " in critical state!"
					return_code = tempcode
				end if

				' Add performance data string
				perfdata = perfdata & "'" & arrSensorArgs(j) & "'=" & value & ";" & threshold_warning & ";" & threshold_critical & ";; "
				exit for
			end if

		end if
	next


	if labelFound = 0 then
		return_code = 3
		message = "Sensor " & arrSensorArgs(j) & " missing"
	end if
	
next

np.nagios_exit message & "|" & perfdata, return_code

