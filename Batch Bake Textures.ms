/*
[INFO]

NAME = Batch Bake Textures
VERSION = 1.0.1
AUTHOR = MastaMan
DEV = ViscoCG
HELP = 

[1.0.0]

* First release =

[ABOUT]

Bake textures for selected objects, which have already been set.=

[TEST]
Test functionality

[SCRIPT]

*/


try(closeRolloutFloater fBatchBakeTextures)catch()
global fBatchBakeTextures = newRolloutFloater "Batch Bake Textures" 250 370
	
fn getScriptInfo s releaseInfo: "" =
(		
	if(releaseInfo != "") do
	(
		r = getINISetting s releaseInfo
		return r
	)
	
	v = getINISetting s "INFO" "VERSION"
	a = getINISetting s "INFO" "AUTHOR"
	n = getINISetting s "INFO" "NAME"
	o = getINISetting s "ABOUT"
	c = getINISetting s "INFO" "DEV"
	h = getINISetting s "INFO" "HELP"
	
	r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
	
	return #(n, a, v, o, r, c, h)
)

fn parseIniLine m = 
(
	if(m.count == 0) do return ""
	
	l = ""	

	try
	(
		for i in m do 
		(	
			if(i[1] == "_") do 
			(
				l += "_______________________________________\r\n\r\n" 
				continue
			)
			if(i[1] == "@") do 
			(
				l += "\r\n"
				continue
			)
			
			l += i + "\r\n"
		)
	) catch()
	return l
)

fn useSettings k p w =
(	
	d = getFilenamePath  (getThisScriptFilename())
	n = filenameFromPath (getThisScriptFilename())			
	settingsFile = d + @"ini\" + (sysInfo.username) + "_" + n + ".ini"
	szUser = sysInfo.computername
	case w of
	(
		"r":
		(
			s = getINISetting settingsFile szUser k
			case p of
			(
				"int": return s as integer
				"float": return s as float
				"bool": if s == "true" then true else false
				default: return s
			)
		)
		default: return setINISetting settingsFile szUser k (p as string)
	)
)

fn freezeUi =
(
  	source = ""
  	source += "using System;\n"
  	source += "using System.Runtime.InteropServices;\n"
  	source += "class WindowsGhosting\n"
  	source += "{\n"
  	source += " [DllImport(\"user32.dll\")]\n"
  	source += " public static extern void DisableProcessWindowsGhosting();\n"
  	source += "}\n"
  
  	csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
  	compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
  
  	compilerParams.GenerateInMemory = on
  	compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source)
  
  	assembly = compilerResults.CompiledAssembly
  	windowsGhosting = assembly.CreateInstance "WindowsGhosting"
  	windowsGhosting.DisableProcessWindowsGhosting()
)

rollout rBatchBakeTextures "Options" 
(
	group "Save Textures To"
	(
		edittext edtBrowse "" width:223 height:25 readOnly:true text: "Please select folder" offset: [-7, 0]
		button btnBrowse "Browse" width:220 height:35	
	)
	group ""
	(
		spinner spnTexSize "Out size:" range: [128, 9999999999, 512] type: #integer fieldWidth: 70 align: #left
		checkbox cbxShowProgressBar "Show Progress Bar"
		checkbox cbxShowVFB "Show VFB"
	)
	button btnStart "Start" width:220 height:35	offset: [0, 10]
	label lblStatus "" offset: [0, 10]
	
	global szOutFolder = ""
	
	fn disableUI d =
	(
		for i in rBatchBakeTextures.controls do i.enabled = d
	)
	
	fn BatchBakeTextures size: 512 progress: false vfb: false =
	(
		objs = selection as array
		
		if(objs.count == 0) do return messageBox "Please select objects!" title: "Warning!"
		if(szOutFolder.count < 2) do return messageBox "Please select output path!" title: "Warning!"
		
		m = VrayMtl()

		c = 1 		
		
		for s in objs where isValidNode s do
		(			
			select s
			bakeTex = s.INodeBakeProperties
			
			n = bakeTex.numBakeElements()
			
			lblStatus.caption = c as string + "/" + objs.count as string
			
			if(n == 0) do continue
			
			for i in 1 to n do 
			(	
				el = bakeTex.getBakeElement i
				
				--el.fileName 
				el.fileType = szOutFolder + @"\" + (filenameFromPath el.fileType)
			)
						
			bakeTex.bakeEnabled = true
			bakeTex.bakeChannel = 2
			bakeTex.nDilations = 2	
									
			originalMat = s.material
			s.material = m
						
			render rendertype:#bakeSelected frame: sliderTime outputSize: [size, size] vfb: vfb progressBar: progress  filterMaps: off antiAliasFilter: (catmull_rom())
				
			s.material = originalMat
							
			c += 1
		)
	)
	
	on btnStart pressed do
	(
		freezeUi()
		disableUI false
		
		s = spnTexSize.value
		p = cbxShowProgressBar.checked
		v = cbxShowVFB.checked
		
		BatchBakeTextures size: s progress: p vfb: v
		
		disableUI true
	)
	
	on btnBrowse pressed do
	(		
		d = getSavePath caption:"Browse"	  initialDir: szInitalDir
		
		if(d == undefined) do return false
		
		edtBrowse.text = d
		
		szOutFolder = d
	)
)

rollout rAbout "About" 
(	
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	button btnHelp "Help" enabled: false
	
	fn getHelp run: false =
	(
		s = getThisScriptFilename()
		i = getScriptInfo s
		
		szHelp = i[7]
		
		if(findString i[7] "http://" == undefined and findString i[7] "https://" == undefined and szHelp.count != 0) do
		(
			szHelp = (getFilenamePath s) + i[7]
			if(not doesFileExist szHelp) do szHelp = ""
		)

		if(szHelp.count != 0) do btnHelp.enabled = true
			
		if(run) do ShellLaunch szHelp ""
	)
	
	on btnHelp pressed do getHelp run: true
				
	on rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
		
		getHelp()
	)
)

addRollout rBatchBakeTextures fBatchBakeTextures rolledUp:false 
addRollout rAbout fBatchBakeTextures rolledUp:true 



