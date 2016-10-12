/*
[INFO]

NAME = Batch Bake Textures
VERSION = 1.0.3
AUTHOR = MastaMan
DEV = ViscoCG
HELP = 

[1.0.0]

* First release =

[1.0.3]
+ Added: Setup bake elements feature=

[ABOUT]

Bake textures for selected objects, which have already been set.=

[TEST]
Test functionality

[SCRIPT]

*/


try(closeRolloutFloater fBatchBakeTextures)catch()
global fBatchBakeTextures = newRolloutFloater "Batch Bake Textures" 250 600
global bakeElements = #("", VRayGlobalIlluminationMap(), VRayTotalLightingMap())
	
global rBatchBakeTextures

	
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

fn fwdSelectionChanged =
(
	sel = #()
	types = #()
	size = #()
	
	rBatchBakeTextures.btnStart.enabled = true
	
	if(selection.count == 0) do
	(
		rBatchBakeTextures.lbxElements.selection = #{1}
		rBatchBakeTextures.ddlFormat.selection = 1
		rBatchBakeTextures.ddlTexSize.selection = 1
		rBatchBakeTextures.btnStart.enabled = false
	)
	
	objs = selection as array	
	for o in objs where isValidNode o do
	(
		n = o.numBakeElements() 
		for i in 1 to n do
		(
			el = o.getBakeElement i			
			c = classOf el as string
			d = el.outputSzX as string + "x" + el.outputSzY as string 
			itemsEl = rBatchBakeTextures.lbxElements.items
			itemsFormat = rBatchBakeTextures.ddlFormat.items
			itemsSize = rBatchBakeTextures.ddlTexSize.items
			
			f = findItem (itemsEl) c
			if(f != 0) do appendIfUnique sel f
			
			f = findItem (itemsFormat) (trimLeft (getFileNameType el.fileType) ".")
			if(f != 0) do append types f
			
			f = findItem (itemsSize) d
			if(f != 0) do append size f	
		)
	)
	
	rBatchBakeTextures.lbxElements.selection = #{1}
	rBatchBakeTextures.ddlFormat.selection = 1
	rBatchBakeTextures.ddlTexSize.selection = 1
	
	if(sel.count > 0) do
	(	
		a1 = makeUniqueArray types		
		if(a1.count != 1) do return false
		a2 = makeUniqueArray size		
		if(a2.count != 1) do return false
		
		rBatchBakeTextures.lbxElements.selection  = sel
		
		rBatchBakeTextures.ddlTexSize.selection = a2[1]
		rBatchBakeTextures.ddlFormat.selection = a1[1]
	)
)
rollout rBatchBakeTextures "Options" 
(
	group "Save Textures To"
	(
		edittext edtBrowse "" width:223 height:25 readOnly:true text: "Please select folder" offset: [-7, 0]
		button btnBrowse "Browse" width:220 height:35	
	)
	group "Selected Objects Common Settings"
	(		
		multilistbox lbxElements "Texture Elements:"
		dropdownlist ddlFormat "Format:" items: #("", "exr", "jpg", "png", "tiff", "tga") across: 2
		dropdownlist ddlTexSize "Out size:"
		button btnSet "Set" width: 70 across: 2		
		button btnClear "Clear" width: 70
	)
	
	group "Render"
	(
	
		checkbox cbxShowProgressBar "Show Progress Bar"
		checkbox cbxShowVFB "Show VFB"
		button btnStart "Start" width:220 height:35	offset: [0, 4]
	)
	
	label lblStatus "" offset: [0, 10] width: 210
		
	global iWindowPos = [0,0]
		
	fn disableUI d all: false =
	(
		for i in rBatchBakeTextures.controls do i.enabled = d
			
		if(not all) do
		(
			edtBrowse.enabled = true
			btnBrowse.enabled = true
			cbxShowProgressBar.enabled = true
			cbxShowVFB.enabled = true
			btnStart.enabled = true
		)
	)
	
	fn saveWindowPos =
	(
		useSettings "X"  iWindowPos[1] "w"
		useSettings "Y"  iWindowPos[2] "w"		
	)
	
	fn getTexSize =
	(
		a = filterString (ddlTexSize.selected) "x"
		return a[1] as integer
	)
	
	fn isSelected =
	(
		s = selection as array
		if(s.count == 0) do 
		(
			messageBox "Please select objects!" title: "Warning!"
			return false
		)
		return true
	)
	
	fn getTexElements = 
	(
		z = #()
		for el in bakeElements do 
		(	
			k = el as string
			a = filterString k ":"
			
			if(a[2] == undefined) then append z "" else append z a[2]
		)
		
		lbxElements.items = z
	)
	
			
	fn BatchBakeTextures size: 512 progress: false vfb: false =
	(
		objs = selection as array
		
		if(not isSelected()) do return false
		if(findString edtBrowse.text ":\\" == undefined) do return messageBox "Please select output path!" title: "Warning!"
		
		m = VrayMtl()

		c = 1
		skip = 0
		
		for s in objs where isValidNode s do
		(			
			select s
			bakeTex = s.INodeBakeProperties
			
			n = bakeTex.numBakeElements()
						
			if(n == 0) do 
			(
				skip += 1
				continue
			)
			
			lblStatus.caption = ("Baking: " + (c as string) + "/" + (objs.count as string) +  " | Skip:  " + (skip as string))
			
			el = bakeTex.getBakeElement 1	
			sizeX = el.outputSzX
			sizeY = el.outputSzY
										
			originalMat = s.material
			s.material = m
						
			render rendertype:#bakeSelected frame: sliderTime outputSize: [sizeX, sizeY] vfb: vfb progressBar: progress  filterMaps: off antiAliasFilter: (catmull_rom())
				
			s.material = originalMat
							
			c += 1
		)
		
		select objs
		
		shellLaunch (edtBrowse.text) ""
	)
	
	on btnSet pressed do
	(
		if(not isSelected()) do return false
		s = lbxElements.selection as array
		items = lbxElements.items
					
		if(s[1] == undefined or (s[1] == 1 and s[2] == undefined)) do return messageBox "Please select texture elements!" title: "Warning!"
		if(ddlFormat.selected == "") do return messageBox "Please select format!" title: "Warning!"
		if(ddlTexSize.selected == "") do return messageBox "Please select out size!" title: "Warning!"
		
		objs = selection as array
		for o in objs where isValidNode o do
		(	
			o.iNodeBakeProperties.removeAllBakeElements()  
			
			for i in s where items[i] != "" do
			(
				p = edtBrowse.text + o.name + "_" + items[i] + "." + ddlFormat.selected
				
				bake = copy bakeElements[i]
				bake.outputSzX = bake.outputSzY = getTexSize()				
				bake.fileType = p
				bake.fileName = filenameFromPath p
				bake.enabled = true				
									
				o.INodeBakeProperties.addBakeElement bake 
				o.INodeBakeProperties.bakeChannel = 2				
				o.INodeBakeProperties.nDilations = 2				
			)
		)
		
		messageBox "Bake Elements setup success!" title: "Success!" beep: false
	)
	
	on btnClear pressed do
	(
		if(not isSelected()) do return false
		objs = selection as array	
		for o in objs where isValidNode o do o.iNodeBakeProperties.removeAllBakeElements()  
		fwdSelectionChanged()
		
		messageBox "All Bake Elements are cleared!" title: "Success!" beep: false
	)
	
	on btnStart pressed do
	(
		freezeUi()
		disableUI false all: true
		
		p = cbxShowProgressBar.checked
		v = cbxShowVFB.checked
		
		BatchBakeTextures progress: p vfb: v
		
		disableUI true
	)
	
	on btnBrowse pressed do
	(		
		d = getSavePath caption:"Browse"	 initialDir: (edtBrowse.text)
		
		if(d == undefined) do return false
		
		
		edtBrowse.text = d +  @"\"
				
		useSettings "INITIALDIR" (edtBrowse.text) "w"
	)
	
	on rBatchBakeTextures close do
	(
		callbacks.removescripts id:#fwdSelectionChanged
		saveWindowPos()
	)
		
	on rBatchBakeTextures open do
	(		
		callbacks.removescripts id:#fwdSelectionChanged
		callbacks.addScript #selectionSetChanged "fwdSelectionChanged()" id:#fwdSelectionChanged persistent:false	
		
		x = useSettings "x" "float" "r"
		y = useSettings "y" "float" "r"
		
		i = useSettings "INITIALDIR" "string" "r"
		if(i.count > 0) do edtBrowse.text = useSettings "INITIALDIR" "string" "r"
		
		cbxShowProgressBar.checked = useSettings "PROGRESS" "bool" "r"
		cbxShowVFB.checked = useSettings "VFB" "bool" "r"
		
		if(x != 0.0 and y != 0.0) do fBatchBakeTextures.pos = [x, y]
		
		res = #("")
		iterator = 256
		for r in 1 to 10 do
		(			
			n =iterator as string
			append res (n + "x" + n)
			iterator += 256
		)
		
		ddlTexSize.items = res
				
		getTexElements()
		
		fwdSelectionChanged()
	)
	
	on rBatchBakeTextures moved p do
	(
		iWindowPos = p
	)	
	
	on cbxShowProgressBar changed v do useSettings "PROGRESS" v "w"
	on cbxShowVFB changed v do useSettings "VFB" v "w"	
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



