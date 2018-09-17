/*  
[INFO] 

NAME = Door Placer
VERSION = 1.4.0
AUTHOR = Vasiliy Lukyanenko
DEV = VISCO
HELP = help\doorPlacer.html

[1.0.0]

* First release =

[1.3.0]

* Adopted for new Scripts Launcher=
* Added load default windows template feature=

[1.4.0]

* Added: Support for UE (scale door mode)=

[ABOUT]

This script helps to quickly place =
doors in a 3Ds Max scene. =
@=
 Features:=
- Doors list=
- Manual door placement with a snap=
- Flip window on local axes (X, Y, Z)=
- "Doors Setup" tool=
__=
ToDo:=
- Write Help=

[SCRIPT]
*/	


try(closeRolloutFloater rDoorPlacer) catch()
global rDoorPlacer = newRolloutFloater "Door Placer" 230 600
global szTemplateDoors = ""

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

fn parseToLine m = 
(
	if(m.count == 0) do return ""
	
	l = ""				
	for i in m do l += i + "\n"
	return l
)

rollout rDoorWindowPlacer "Place" 
(
	listbox lbxList ""  height:8
	button btnPlace "Place " enabled: true width: 190 height: 40 
	
	group "Mode" (
		radiobuttons rdoPlaceType "" labels: #("Vertex Move", "Scale") default: 2
	)
	
	group "Z Position"
	(
		checkbox cbxUseZ "Use Z Position"
		spinner spnZPos "Z Position:" range:[0.0,99999999,0]  fieldWidth: 60 align: #left type:#worldunits enabled: false
	)	
	group "Tip"
	(
		label lblTip "" align: #left height: 45 offset: [0, 0]
	)

	group "Mirror"
	(
		button btnFlipX "Flip X" across: 4 offset: [0, 8]
		button btnFlipY "Flip Y" offset: [0, 8]
		button btnFlipXY "Flip XY" offset: [0, 8]
		button btnUnflip "Unflip" offset: [0, 8]
	)
	group "Template"
	(
		label lblTip2 "You can load to scene default\ncustomized doors." height: 35 align: #left
		button buttonLoadToScene "Load To Scene"  enabled: false
	)
	label lblEmpty ""
	
	global Obj = #()
	global DoorConstraint = #()
	
	fn flipObject a =
	(				
		for s in selection do
		(			
			if(a == -1) do
			(
				if(classOf s.modifiers[1] == Mirror) do deleteModifier s 1
				continue
			)
			
					
			try
			(
				s.modifiers[#Mirror].mirror_axis = a		
			)
			catch
			(
				m = Mirror()
				m.mirror_axis = a 
				addModifier s m
			)
			
			try(update s)catch()
		)
	)
	
	fn showTip x =
	(
		m = ""
		b = ""
		dt = DoorConstraint[x][6]
		dpt = DoorConstraint[x][8]
		
		rdoPlaceType.state
		
		if(dt != "") do b = "\nThen set thickness."
		if(dpt != "") do m = "Door: " + Obj[x].name + ".\nPlace on top view, start from hinge." + b 
				
		lblTip.caption = m
	)
	
	on lbxList selected x do
	(
		if(x != 0) do showTip x
	)
	
	on btnFlipX pressed do flipObject 0
	on btnFlipY pressed do flipObject 1
	on btnFlipXY pressed do flipObject 3
	on btnUnflip pressed do flipObject -1
	
	on cbxUseZ changed x do
	(
		spnZPos.enabled = x
	)
	
	fn initPlacer =
	(
		Obj = #()
		lbxList.items = #()
		Constraint = #()
		
		fn getPropArray p o =
		(
			a = #()
			
			try(a = for z in (filterString (getUserProp o p) ", ") collect z as integer) catch(a = "")
			
			return a
		)
		
		fn getPropMatrix p o =
		(
			return try(execute (getUserProp o p)) catch(undefined)
		)
		
		fn getPropOffset p o =
		(
			a = 0.0
			try(a = (getUserProp o p) as float) catch()
			return a
		)
				
		for i in geometry where classOf i == Editable_Poly and ((getUserProp i "door_place_type") == rdoPlaceType.state)   do
		(
			append Obj i
			
			d = #()
			d[1] = getPropArray "door_r" i
			d[2] = getPropArray "door_l" i
			d[3] = getPropArray "door_t1" i
			d[4] =  getPropArray "door_t2" i			
			d[5] =  getPropOffset "door_w" i
			d[6] = getPropOffset "door_t" i
			d[7] = getPropArray "door_h" i			
			d[8] = getUserProp i "door_place_type"
						
			append DoorConstraint d
		)
				
		lbxList.items =  for i in Obj collect i.name
		try(showTip 1)catch()
	)
	
	on rdoPlaceType changed v do (
		initPlacer()	
	)
	
	on rDoorWindowPlacer open do
	(		
		initPlacer()
		
		szTemplateDoors = (getFilenamePath (getThisScriptFilename())) + "help\\doorPlacer\\doorPlacerTemplate.max"				
		if(doesFileExist szTemplateDoors) do buttonLoadToScene.enabled = true
	)
	
	on buttonLoadToScene pressed do
	(
		if(queryBox "Merge default doors to scene?" title: "Template" and doesFileExist szTemplateDoors) do
		(
			disableSceneRedraw()
			mergeMAXFile szTemplateDoors #select #promptDups #renameMtlDups quiet: true
			toolMode.selectioncenter() 
			enableSceneRedraw()
			max tool zoomextents all
			initPlacer()
		)
	)
	
	global TapeCount = 0
	
	fn placeDoor =
	(
		undo off
		(
			fn tapeCallback o =
			(
				TapeCount += 1
				if(TapeCount > 2) do stopCreating()
			)
					
			n = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback						
		)
				
		undo off
		(			
			if(classOf n[2] == Targetobject) do 
			(
				i = lbxList.selection
				r = DoorConstraint[i][1]
				l = DoorConstraint[i][2]
				t1 = DoorConstraint[i][3]
				t2 = DoorConstraint[i][4]
				dw = DoorConstraint[i][5]
				dt = DoorConstraint[i][6]
				dh = DoorConstraint[i][7]
				dm = DoorConstraint[i][8]
								
				try(s = copy Obj[i]) 
				catch
				(
					messageBox "Object not exist!"
					return false
				)
				
				w1 = distance n[1] n[2]
				
				iWidth = (dw - w1) / 2.0
				
				try(polyop.moveVert s r [-iWidth, 0, 0]) catch()
				try(polyop.moveVert s l [iWidth, 0, 0]) catch()
				
				if(dm != undefined) do try(in coordsys dm polyop.moveVert s dh [0, 0, (iWidth * 2.0)]) catch()
												
				s.pivot.z = s.min.z
															
				tr = s.transform
				tr.row1 = n[1].transform.row1
				tr.row2 = n[1].transform.row2
				tr.row3 = n[1].transform.row3
					
				s.transform = tr
					
				in coordsys local rotate s (EulerAngles -90 0 0)
				in coordsys local rotate s (EulerAngles 0 0 90)		
								
				p = n[1].pos  - ((n[1].pos - n[1].target.pos) / 2.0)
												
				try(delete n) catch()
				
				s.pos.x = p.x
				s.pos.y = p.y
				s.pos.z = p.z
						
				if(cbxUseZ.checked == true) do s.pos.z = spnZPos.value				
				
				if(t1 != "" and t2 != "") do
				(										
					TapeCount = 0
								
					k = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback			
										
					if(classOf k[2] == Targetobject) do 
					(								
						w1 = distance k[1] k[2]
						iWidth = abs((dt - w1) / 2)
											
						try(in coordsys s polyop.moveVert s t1 [0, -iWidth, 0]) catch()
						try(in coordsys s polyop.moveVert s t2 [0, iWidth, 0]) catch()
																		
						try(delete k) catch()
					)	
				)					
			)
		)

		TapeCount = 0
		try(select s) catch()
	)
	
	fn roundTo v t: 100 = (	
		v = v as float
		t = t as float
		v = (ceil (v * t)) as integer
		return  v / t 
	)
	
	fn placeDoorScale = (
		undo off
		(
			fn tapeCallback o =
			(
				TapeCount += 1
				if(TapeCount > 2) do stopCreating()
			)
					
			n = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback						
		)
				
		undo off
		(			
			if(classOf n[2] == Targetobject) do 
			(
				i = lbxList.selection
				
				dw = DoorConstraint[i][5]
				dt = DoorConstraint[i][6]
			
								
				try(s = instance Obj[i]) 
				catch
				(
					messageBox "Object not exist!"
					return false
				)
				
				w1 = distance n[1] n[2]					
				sy = ((w1 - dw) / dw) + 1.0
				
				sy = roundTo sy t: 10000
																
				s.pivot.z = s.min.z
															
				tr = s.transform
				tr.row1 = n[1].transform.row1
				tr.row2 = n[1].transform.row2
				tr.row3 = n[1].transform.row3
					
				s.transform = tr
				
				scale s [1, sy, 1]
					
				in coordsys local rotate s (EulerAngles -90 0 0)
				in coordsys local rotate s (EulerAngles 0 0 90)		
								
				p = n[1].pos  - ((n[1].pos - n[1].target.pos) / 2.0)
												
				try(delete n) catch()
				
				s.pos.x = p.x
				s.pos.y = p.y
				s.pos.z = p.z
						
				if(cbxUseZ.checked == true) do s.pos.z = spnZPos.value				
				
				if(dt != "") do
				(										
					TapeCount = 0
								
					k = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback			
										
					if(classOf k[2] == Targetobject) do 
					(								
						w1 = distance k[1] k[2]
						
						sx = ((w1 - dt) / dt) + 1.0				
						sx = roundTo sx t: 10000
						
						s.scale.y = sx

						try(delete k) catch()
					)	
				)					
			)
		)

		TapeCount = 0
		try(select s) catch()
	)
	
	
	on btnPlace pressed do
	(			
		i = lbxList.selection
		
		
		case rdoPlaceType.state of (
			1: (				
				dr = DoorConstraint[i][1]
				dl = DoorConstraint[i][2]
					
				if(dr != "" and dl != "") do placeDoor()							
			)
			2: (
				dw = DoorConstraint[i][5]
				
				if(dw != "") do placeDoorScale()	
			)
		)
		
		
	)
)

rollout rDoorSetup "Door Setup" 
(
	group "Setup Doors Type" (
		radiobuttons rdoPlaceType "" labels: #("Vertex Move", "Scale") default: 2
	)
	
	group "Size Setup"
	(
		button btnAddTWidth "Add Width"
		button btnAddThickness "Add Thickness (Optional)"	
	)
	
	group "Vertex Sets"
	(
		button btnAddRightVert "Add Right Vertex"
		button btnAddLeftVert "Add Left Vertex"
		button btnAddTVert1 "Add Thickness + (Optional)"
		button btnAddTVert2 "Add Thickness - (Optional)"
	)
		
	group "Specify opening part"
	(
		button btnAddDoorEdge "Add Door Edge Vertex"
		button btnAddDoorWidth "Add Door Vector"
	)
	
	group "Tip:"
	(
		label lblTip "Set pivot in center and \nbottom of door!" height: 30 align: #left
	)
	
	fn toggleInterface = (			
		v = rdoPlaceType.state

		btnAddTWidth.enabled = true
		btnAddThickness.enabled = true

		btnAddRightVert.enabled = v != 2
		btnAddLeftVert.enabled = v != 2
		btnAddTVert1.enabled = v != 2
		btnAddTVert2.enabled = v != 2		
		btnAddDoorEdge.enabled = v != 2		
		btnAddDoorWidth.enabled = v != 2		
	)
	
	fn setUserPropVert n =
	(
		try
		(			
			a = ($.EditablePoly.GetSelection #Vertex) as array
			z = ""
			for i in a do z += i as string + ","
			setUserProp $ n (z as string)		
			setUserProp s "door_place_type" rdoPlaceType.state
			messageBox ("Added " + a.count as string + " points!")			
			
			rDoorWindowPlacer.initPlacer()
		)
		catch
		(
			messageBox "Error!!"
		)
	)
	
	fn setUserPropMatrix n =
	(
		s = selection[1] 
		if(s == undefined) do
		(
			messageBox "Please select object"
			return false
		)
		
		try
		(			
			undo off
			(
				fn tapeCallback o =
				(
					TapeCount += 1
					if(TapeCount > 2) do stopCreating()
				)
					
				t = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback			
				
				if(classOf t[2] == Targetobject) do 
				(									
					setUserProp s n (t[1].transform as string)
					setUserProp s "door_place_type" rdoPlaceType.state					
									
					try(delete t) catch()
					select s
					TapeCount = 0
					
					messageBox "OK"
				)
			)

			rDoorWindowPlacer.initPlacer()			
		)
		catch
		()
	)
	
	fn setUserPropOffset n =
	(
		s = selection[1] 
		if(s == undefined) do
		(
			messageBox "Please select object"
			return false
		)
		
		try
		(			
			undo off
			(
				fn tapeCallback o =
				(
					TapeCount += 1
					if(TapeCount > 2) do stopCreating()
				)
					
				t = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback			
				
				if(classOf t[2] == Targetobject) do 
				(	
					o = distance t[1] t[2]
				
					setUserProp s n (abs o)	
					setUserProp s "door_place_type" rdoPlaceType.state
									
					try(delete t) catch()
					select s
					TapeCount = 0
					
					messageBox ("Offset " + (abs o) as string)
				)
			)

			rDoorWindowPlacer.initPlacer()			
		)
		catch
		()
	)
	
	on rDoorSetup open do (
		toggleInterface()
	)
	
	on rdoPlaceType changed v do (
		toggleInterface()			
	)
	
	
		on btnAddRightVert pressed do setUserPropVert "door_r "
		on btnAddLeftVert pressed do setUserPropVert "door_l "
		on btnAddTVert1 pressed do setUserPropVert "door_t1 "	
		on btnAddTVert2 pressed do setUserPropVert "door_t2 "
		
		on btnAddTWidth pressed do setUserPropOffset "door_w"		
		on btnAddThickness pressed do setUserPropOffset "door_t"	
			
		on btnAddDoorEdge pressed do setUserPropVert "door_h"
		on btnAddDoorWidth pressed do setUserPropMatrix "door_m"
)

rollout _rAbout "About" 
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
		szHelp = (getFilenamePath s) + i[7]
		if(doesFileExist szHelp) do btnHelp.enabled = true
			
		if(run) do ShellLaunch szHelp ""
	)
	
	on btnHelp pressed do getHelp run: true
		
	on _rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
		
		getHelp()
	)
)

addRollout rDoorWindowPlacer rDoorPlacer rolledUp:false 
addRollout rDoorSetup rDoorPlacer rolledUp:true 
addRollout _rAbout rDoorPlacer rolledUp:true 

