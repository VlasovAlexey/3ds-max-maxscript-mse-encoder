

-- encryptScript  "Decal_Projector087.ms"


global DP_version = "0.87o"

global  SelectMapDialog, DPTargetObj_rollout,   DPRectangle_rollout,  DPBake_rollout, DPetc_rollout, DPoption_rollout, DPPaint_rollout
global oriObj,  real_oriObj
global  dp_PaintTool




fn TargetGeometry =
(
	if DPTargetObj_rollout.obj == undefined do return undefined
	if isDeleted DPTargetObj_rollout.obj do return undefined
	if superclassof DPTargetObj_rollout.obj != GeometryClass do return undefined
	if classof DPTargetObj_rollout.obj == Biped_Object or classof DPTargetObj_rollout.obj == BoneGeometry do return undefined 
	
	DPTargetObj_rollout.obj
)



rollout DpAbout_rollout "About"
(
	fn replaceAllstring str  findstr  replaceStr =
	(
		local newStr= copy str
		if findstr.count == 0 do return newStr
		
		count = 0
		while true do
		(
			if keyboard.escPressed do exit
			if count > 1000 do exit
			count += 1	
			
			f = findstring  newStr  findstr
			if f != undefined then
			(
				newStr = replace newStr  f findstr.count  replaceStr
			)
			else exit
		)
		newStr				-- 최종적으로 return
	)
	
	
	fn logoFn =
	(
		local dir = getdir #scripts + "/DecalProjector/icons/about logo.png"
		ob = openbitmap dir
	)
	button about_btn "" width:170 height:30  images:#(logoFn(), undefined, 1,1,1,1,1 )

	on about_btn pressed do
	(
		txt = "   [][][][][][][][]        Decal Projector   v###version      [][][][][][][][]\n\n
	Created by OYH in 2011.10
		
		
		
	more infomation:
	http://cafe.daum.net/maxscript
	"
		txt = replaceAllstring txt "###version"  DP_version
		messagebox txt
	)
)




rollout SelectMapDialog "Select BitmapTexture"
(
	local texlist = #()
	local selectedMap = undefined
	
	listbox texList_lb ""  width:400 height:10  pos:[10,10]
	bitmap preview_map "" width:100 height:100 pos:[430,20]
	button  choice_btn "Choice Texture" pos:[230,200] width:100 height:30

	fn collectMtls  mat  &matArray =
	(
		numMat = getNumSubMtls mat
		
		for i in 1 to numMat do
		(
			mt = getSubMtl mat i
			if mt != undefined  do
			(	
				num = getNumSubMtls mt
				if num > 0 then
					collectMtls mt  &matArray
				else
					append matArray mt	
			)		
		)
	)
	
	fn collectTexMaps  MaterialOrTexture  &texArray =
	(
		numMap = getNumSubTexmaps MaterialOrTexture
		
		for i in 1 to numMap do
		(
			tex = getSubTexmap MaterialOrTexture i
			if tex != undefined  do
			(			
				if classof tex == bitmaptexture do
					append texArray tex
				
				num = getNumSubTexmaps MaterialOrTexture
				if num > 0 do
					collectTexMaps tex  &texArray
			)		
		)
	)
	
	fn setTexMap  MaterialOrTexture  findMap  replaceMap  =
	(
		numMap = getNumSubTexmaps MaterialOrTexture
		
		for i in 1 to numMap do
		(
			tex = getSubTexmap MaterialOrTexture i
			if tex != undefined  do
			(			
				if tex == findMap do
					setSubTexmap MaterialOrTexture i  replaceMap
				
				num = getNumSubTexmaps MaterialOrTexture
				if num > 0 do
					setTexMap  tex  findMap  replaceMap
			)		
		)
	)	

	fn previewFn  idx =
	(
		if texlist[idx] != undefined and texlist[idx].bitmap != undefined do
		(
			newMap = bitmap 100 100
			copy texlist[idx].bitmap newMap
			preview_map.bitmap = newMap
		)		
	)
	
	fn doSet  mat =
	(
		matArray = #(mat)
		collectMtls  mat  &matArray
		
		for m in matArray do
		(
			mytexArray = #()
			collectTexMaps m &mytexArray
			
			join texlist mytexArray
		)
				
		texNames = for i in texlist collect
		(
			n = i.name
			while true do
			(
				size = gw.getTextExtent n
				if size.x > 150 do exit
				n += " "
			)
			
			n + " " + filenameFromPath (i.filename)
		)
		texList_lb.items = texNames
		
		previewFn 1
	)
	
	
	
	on texList_lb selected val do
	(
		previewFn val
	)
	
	on texList_lb doubleClicked  val do
	(
		if texlist[val].bitmap != undefined do
			display texlist[val].bitmap
	)
	
	on choice_btn pressed do
	(
		idx = texList_lb.selection
		if texlist[idx].bitmap == undefined do return undefined
		selectedMap = texlist[idx]
		
		try( destroydialog SelectMapDialog ) catch()
	)
	
	on SelectMapDialog open do
	(
		if DPTargetObj_rollout.Obj.material != undefined do
			doSet DPTargetObj_rollout.Obj.material
	)
)






rollout DPTargetObj_rollout "Target Object"
(
	local Obj = undefined
	fn filt_obj obj = superclassof obj == GeometryClass

	pickbutton pickObj_pb "Pick Object"   width:150  filter:filt_Obj  autoDisplay:true
	
	on pickObj_pb picked obj_ do
	(
		if obj_.material == undefined do
		(
			messagebox "No Material.."
			return undefined
		)
		
		Obj = obj_
		
		DPRectangle_rollout.start_ch.enabled = true
		DPPaint_rollout.draw_ch.enabled = true
		
		for i in sceneMaterials do
		(
			if i.name == "dp_mtl" do
				i.name = "new material"
		)
		
		try( createdialog SelectMapDialog width:550 height:250 )catch()
	)
)





global g_isTransform = false
global toolObj, toolSc=#()
global objRay_bak

tool DPtool
(
 	local isBtnStop = false
	local bak_scale = 1
	local bak_rot = 0

	
	fn EndTool = 
	(
		isBtnStop = true
		#stop
		DpRectangle_rollout.start_ch.checked = false

		try( delete toolObj )catch()
		delete $dp_oriObj*
		delete $dp_selectFaces*
		oriObj = real_oriObj

		DpRectangle_rollout.dpCount = 0
	)
	
	fn addSlice  val =
	(
		myName = "slice" + val as string
		toolObj.name = uniqueName "DecalPlusObj"
		addmodifier toolObj (sliceModifier name:myName)
		toolSc[val] = toolObj.modifiers[myName as name]
		modTM=getModContextTM toolObj toolSc[val]			-- not use
	)
	
	fn SetSlicePlane  objRay  val  shiftPos  rot  =
	(
		rotMat = rotateZMatrix  rot
		
		view = getViewTM()
		inView = inverse view
		inView = rotMat * inView

		
		if objRay_bak != undefined then
			offsetPos = objRay_bak.pos
		else
			offsetPos = objRay.pos - oriObj.pos		-- center 아님
		
		if val < 3 then
			leftTm = matrix3   inView.row2  inView.row3 inView.row1 offsetPos			-- left, right
		else
			leftTm = matrix3   inView.row3  inView.row1 inView.row2   offsetPos			-- top, bottom
		
		DpRectangle_rollout.gizmoMat = copy (matrix3   inView.row1  -inView.row2  inView.row3  offsetPos)			-- for UVWmap gizmo
		
 		newTm =  transmatrix shiftPos * leftTm
		toolSc[val].Slice_Plane = newTm
		
		
	)

	
	fn drawPlane =
	(
		mapRay = mapScreenToWorldRay mouse.pos
		objRay = intersectRay oriObj mapRay
		
		if shiftKey == false and ctrlKey == false do
			objRay_bak = objRay

			
		if objRay != undefined do
		(

			myWidth = DpRectangle_rollout.width_spi.value
			myHeight = DpRectangle_rollout.height_spi.value			
			myScale = DpRectangle_rollout.scale_spi.value
			myRot = DpRectangle_rollout.rot_spi.value
			
			-- left
			idx = 1
			SetSlicePlane  objRay idx ([0,0,-myWidth/2.0]*myScale)   myRot
			toolSc[idx].Slice_Type = 3
			
			-- right
			idx = 2
			SetSlicePlane objRay idx ([0,0,myWidth/2.0]*myScale)  myRot
			toolSc[idx].Slice_Type = 2
			
			-- top
			idx = 3
			SetSlicePlane objRay idx ([0,0,myHeight/2.0]*myScale)  myRot
			toolSc[idx].Slice_Type = 2
			
			-- bottom
			idx = 4
			SetSlicePlane objRay idx ([0,0,-myHeight/2.0]*myScale)  myRot
			toolSc[idx].Slice_Type = 3
			
			
			-- modify [UVWmap]
			(
				modMap = toolObj.modifiers[#dp_CurMap]

				if modMap != undefined do
				(
					modMap.gizmo.transform = DpRectangle_rollout.gizmoMat
					modMap.length = DpRectangle_rollout.scale_spi.value * myHeight
					modMap.width = DpRectangle_rollout.scale_spi.value * myWidth
				)
			)
			
		)
	)
	
	
	------------------ Events --------------------------
	
	-- start 부분은 에러 생기면 안된다
	-- editable_mesh 이고 subobjectLevel = 3 (face) 에서 버그 생김
	on start do
	(
		if g_isTransform do
		(
			g_isTransform = false
			return undefined
		)
			
		
		if DPTargetObj_rollout.obj != undefined  then
		(
			max create mode
			DpRectangle_rollout.dpCount += 1
			
	
			
			oriObj.material = DPTargetObj_rollout.obj.material
			oriObj.name = "dp_oriObj"
			hide oriObj
			toolObj = copy oriObj
			toolObj.wirecolor = green
			toolObj.name = "tempDP"
			
			addSlice  1
			addSlice  2
			addSlice  3
			addSlice  4
			
			-- add [push]
			addmodifier toolObj (push name:"dp_push" Push_Value:DpRectangle_rollout.push_spi.value)
			
			-- copy material
			toolObj.material = copy DPRectangle_rollout.material_btn.material
			if toolObj.material != undefined  do
			(
				assignNewName toolObj.material
				toolObj.material.showinViewport = true
			)
			
			-- Mask
			if DPoption_rollout.mask_cb.checked  do
			(
				selfaceObj = copy oriObj
				selfaceObj.name = "dp_selectFaces"
				allface = #{1..selfaceObj.faces.count}
				selface = getFaceSelection selfaceObj
				if selface.numberset == 0 do messagebox "do not selected faces"
				meshop.deleteFaces selfaceObj  (allface - selface)
				update selfaceObj

				addmodifier selfaceObj (push name:"dp_push_face" Push_Value:0.03)				
				selfaceObj.material = DpRectangle_rollout.sampleMaterials[999]
			)

			
			drawPlane()
			
			-- add [UVWmap]
			if isDeleted toolObj == false and toolObj.modifiers[#dp_CurMap] == undefined do
			(
				select toolObj			-- UVWmap 은 선택해야 함
				-- 				max modify mode
				
				addmodifier toolObj (UVWmap name:"dp_CurMap")
				modMap = toolObj.modifiers[#dp_CurMap]
	

				select real_oriObj
			)
			
			completeRedraw()
		)
		else
			EndTool()
	)
	
	
	on mousePoint clickno do
	(
		if clickno == 1 then			-- mouse down
		(
			
		)
		else
		(
--  			format "mouse Up\n"
			try( toolObj.wirecolor = random black white )catch()
			
			#stop
		)
	)

	on mouseMove clickno do
	(
-- 		format "mouse drag: %\n" clickno
		if myPoint != undefined do
			myPoint.pos = worldPoint
	)
	
	on freeMove do
	(
		if shiftKey do
		(
			sub = DpRectangle_rollout.mouseOld.y  - mouse.pos.y
			val = 0
			if sub > 0 then 
				val = sub
			else
				val = -sub
			
			g_isTransform = true
			DpRectangle_rollout.scale_spi.value = sub * 0.1 + bak_scale
			drawPlane()
			
			return undefined			
		)
		
		if ctrlKey do
		(
			sub = DpRectangle_rollout.mouseOld.y  - mouse.pos.y
			val = 0
			if sub > 0 then 
				val = sub
			else
				val = -sub
			
			g_isTransform = true
			DpRectangle_rollout.rot_spi.value = sub * 2 + bak_rot
			drawPlane()
			
			return undefined
		)
		
		DpRectangle_rollout.mouseOld = mouse.pos
		bak_scale = DpRectangle_rollout.scale_spi.value
		bak_rot = DpRectangle_rollout.rot_spi.value
		
		
		
		if isBtnStop == true do return undefined
		
		if g_isTransform == false do
			drawPlane()
		
	)
	
	
	on mouseAbort clickno do
	(
-- 		format "mouse About: %\n" clickno
-- 		try( delete toolObj )catch()
		
		if g_isTransform do
		(
			#stop
			isBtnStop = true
		)
		
		EndTool()
	)
	
		
	
	fn postPlane =
	(
		
		if isdeleted toolObj == false do
		(
			toolObj.parent = real_oriObj			--link

			-- select faces to Mask (Editable Poly)
			if DPoption_rollout.mask_cb.checked do
			(
				allface = #{1..oriObj.faces.count}
				selface = getFaceSelection oriObj
				meshop.deleteFaces toolObj  (allface - selface)
				update toolObj
			)
			
			
			-- backface culling
			if DPoption_rollout.backface_cb.checked do
			(
				uvwMod = toolObj.modifiers[#dp_CurMap]
				deleteModifier toolObj uvwMod
				convertToMesh toolObj
				addmodifier toolObj uvwMod
				DPBake_rollout.deleteBackface  toolObj
			)
		)
		
		
	)
	
	
	---=================================================---------------
	on stop do 
	(
-- 		format "stop % \n" isBtnStop
		
		if g_isTransform and isBtnStop do
		(
			#stop
			return undefined
		)
		
		if g_isTransform do
		(
			startTool DPtool
			return undefined
		)
		
		postPlane()
		
		if isBtnStop == false do
			startTool DPtool
	)
	
	
)
--------------- MouseTool...end -----------------




rollout DPRectangle_rollout "Rectangle"
(
	local  mouseOld	= mouse.pos				-- mouse pos
	local  gizmoMat = matrix3 1
	local  sampleMaterials = #()
	local  dpCount = 0

	materialbutton  material_btn "Select Material" width:150  height:0 visible:false	
	colorpicker color_pi "" width:20 height:15 pos:[5,7]  modal:false  color:black
	button preview_btn "" width:35 height:35 pos:[35,7]
	dropdownlist matList_dd "" width:100  height:20  pos:[80,15]  items:#("--------------------------------",		\
		"Shape1","Shape2","Soild1","Soild2","Liner1","Liner2","Circle","Gradient","Circle-Gradient","Dirt1","Dirt2",		\
		"--------------------------------", "Select Material", "Select Bitmap")  selection:2
	
	spinner width_spi "Width" range:[0,1000,5]  pos:[20,15+50] width:70
	spinner height_spi "Height" range:[0,1000,5] pos:[110,15+50] width:70
	spinner scale_spi "Scale " range:[0,1000,1]  pos:[20, 40+50]  width:70
	spinner rot_spi "Rotate " range:[-10000,10000,0] pos:[110, 40+50]  width:70
	spinner push_spi "Push " range:[0,100,0.05]  width:70  visible:false
	checkbutton start_ch "Start" width:140  height:22 pos:[20, 40+80] enabled:false		
		

	fn icon1Fn =
	(
		local dir = getdir #scripts + "/DecalProjector/icons/icon1.bmp"
		ob = openbitmap dir
	)
	fn icon1aFn =
	(
		local dir = getdir #scripts + "/DecalProjector/icons/icon1a.bmp"
		ob = openbitmap dir
	)
	fn icon2Fn =
	(
		local dir = getdir #scripts + "/DecalProjector/icons/icon2.bmp"
		ob = openbitmap dir
	)			

	fn draw_preview  mat = 
	(
		max create mode
		
		renderWidth = 35
		renderHeight = 35
		delete $dpObject_*
		
		baseObj = plane  length:1 width:1  lengthsegs:1  widthsegs:1 name:"dpObject_baseObj"
		baseObj.pos = [0, 0, 0]
		baseObj.material = mat
		
		
		-- 카메라 만들기
		C_camera=Freecamera fov:45 targetDistance:183.3  pos:[0,0,0]  name:"dpObject_cam"
		hfov = C_camera.fov
		vfov = DPBake_rollout.GetCamVFOV  C_camera
		w = 100 * tan(hfov/2)
		l = 100 * tan(vfov/2)
		baseObj.scale.x = 2*w
		baseObj.scale.y = 2*l
		in coordsys C_camera ( baseObj.pos = [0, 0, -100] )
		C_camera.parent = baseObj			--link
		baseObj.pos.z = 0
		

		-------- render ------------------------------------------
		-- bakup Environment
		-- lightLevel : 1.155
		bak_backgroundColor = backgroundColor
		bak_ambientColor = ambientColor
		bak_lightTintColor = lightTintColor
		bak_LightLevel = lightLevel		-- backup LightLevel
		backgroundColor = black
		ambientColor = black
		lightTintColor = white
		lightLevel = 1.155
		
		select #(baseObj)
		
		-- set render
		if RendererClass.classes[1] == Default_Scanline_Renderer do
		(
			renderers.current = RendererClass.classes[1]()
			renderers.production = RendererClass.classes[1]()
		)
					
		half_render=render camera:C_camera  antiAliasFilterSize:0.1  vfb:false  renderType:#selection  shadows:false 
		close half_render
		
		backgroundColor = bak_backgroundColor
		ambientColor = bak_ambientColor
		lightTintColor = bak_lightTintColor
		lightLevel = bak_LightLevel
		
		delete #(baseObj, C_camera)
		
		-- gc light:true 하지 말자 (메모리 누수 생김) 
		gc() 			--freeSceneBitmaps()

-- 		display half_render
		half_render
	)

		
		
	on preview_btn pressed do
	(
		if material_btn.material == undefined do return undefined
			
		MatEditor.Open()
		activeMeditSlot = 1
		medit.UpdateMtlEditorBrackets()
 		meditmaterials[1] = material_btn.material
	)
	
	
	fn selectedMat  i = 
	(
		(																			-- default
			width_spi.value = 5
			height_spi.value = 5
		)
		

		if i == 5 then							-- #soild 5
		(
			width_spi.value = 1000
			height_spi.value = 1000
		)
		else if i == 6 or i ==7 then
		(
			width_spi.value = 100
			height_spi.value = 5
		)
		else if i == 11 or i == 12 then				-- dirt 1 ~ 2
		(
			sampleMaterials[i].opacitymap.noisePhase = random 0.0 10000.0
		)
		
		
		bak_selectObj = selection as array
		if matList_dd.selected == "Select Material" then					-- custom
		(
			mat = materialBrowseDlg #mats
			if mat == undefined do return undefined
			
			material_btn.material = mat
			preMap = DpRectangle_rollout.draw_preview  mat
			preview_btn.images = #(preMap, preMap, 1,1,1,1,1 )			
		)
		else if matList_dd.selected == "Select Bitmap" then
		(
			dir = selectbitmap()
			if dir != undefined do
			(
				sm = standardMaterial  showInViewport:true  name:"selectMap"
				map = bitmaptexture filename:dir.filename
				sm.opacitymap = map
				sm.opacitymap.monoOutput = 1
				sm.diffuse = color 0 0 0
				sm.specular = color 0 0 0
				sm.specularlevel	= 0
				sm.glossiness = 0
				sm.diffusemap = map
				material_btn.material =  sm
				preMap = draw_preview  sm
				preview_btn.images = #(preMap, preMap, 1,1,1,1,1 )
			)
		)
		else
		(
			material_btn.material =  sampleMaterials[i]
			preMap = draw_preview  sampleMaterials[i]
			preview_btn.images = #(preMap, preMap, 1,1,1,1,1 )
		)
		
		select bak_selectObj		
	)
	
	
	on matList_dd selected i do
	(
		selectedMat i

		
		if DPtool.isBtnStop == false do
		(
			-- stop MouseTool
			DPtool.EndTool()
			DPtool.isBtnStop = true
			stopTool DPtool
		)
		
		if material_btn.material != undefined do
			color_pi.color = material_btn.material.diffuse
	)
	
	
	on color_pi changed new_col do
	(
		if material_btn.material == undefined do return undefined
			
		material_btn.material.diffuse = new_col

		i = matList_dd.selection
		bak_selectObj = selection as array
 		preMap = DpRectangle_rollout.draw_preview  DpRectangle_rollout.sampleMaterials[i]
   		preview_btn.images = #(preMap, preMap, 1,1,1,1,1 )
		select bak_selectObj
		
	)	
	
	on material_btn picked mtl do
	(
		material_btn.text = mtl.name
	)
	
	
		
	on DpRectangle_rollout open do
	(
		-------------- delete Lights -------------------
		lightArray = $lights as array
		if lightArray.count > 0 do
		(
			q = queryBox "Delete All Lights?"
			if q then
			(
				delete lightArray
			)
			else
			(
				try( closeRolloutFloater DpNewFloater )catch()
				return undefined
			)
		)
		
		
		sampleMaterials[1] = undefined
		
		-- #2: shape1
		(
			sm = standardMaterial  showInViewport:true  name:"shape1"
			dir = getdir #maxroot + "maps/BIGLEAF3.tga"
			map = bitmaptexture filename:dir
			sm.opacitymap = map
			sm.diffuse = color 180 180 180
			sm.specularlevel	= 0
			sm.glossiness = 0
			sm.specularmap = map
			sampleMaterials[2] = sm
		)

		-- #3: shape2
		(
			sm = standardMaterial  showInViewport:true  name:"shape2"
			dir = getdir #maxroot + "maps/FLOWER6P.tga"
			map = bitmaptexture filename:dir
			sm.opacitymap = map
			sm.diffuse = color 180 180 80
			sm.specularlevel	= 0
			sm.glossiness = 0
			sm.specularmap = map
			sampleMaterials[3] = sm
		)

		-- #4: Soild1
		(
			sm = standardMaterial  showInViewport:true  name:"Soild1"
			sm.diffuse = color 253 253 253
			sm.specularlevel	= 0
			sm.glossiness = 0
			sm.specularmap = map
			sampleMaterials[4] = sm
		)

		-- #5: Soild2
		(
			sm = standardMaterial  showInViewport:true  name:"Soild2"
			sm.diffuse = color 253 253 253
			sm.specularlevel	= 0
			sm.glossiness = 0
			sm.specularmap = map
			sampleMaterials[5] = sm
		)

		-- #6: Liner1
		(
			sm = standardMaterial  showInViewport:true  name:"Liner1"
			sm.diffuse = color 253 253 253
			map = checker()
			map.coords.U_Mirror = true
			map.coords.U_Tiling = 0
			map.coords.V_Tiling = 1
			map.coords.V_Offset = 0.75
			sm.opacitymap = map			
			sm.specularlevel	= 0
			sm.glossiness = 0
			sm.specularmap = map
			sampleMaterials[6] = sm
		)

		-- #7: Liner7		
		(
			sm = standardMaterial  showInViewport:true  name:"Liner2"
			sm.diffuse = color 253 253 253
			map = checker()
			map.coords.U_Mirror = true
			map.coords.U_Tiling = 0
			map.coords.V_Tiling = 2
			map.coords.V_Offset = 0.125
			sm.opacitymap = map			
			sm.specularlevel	= 0
			sm.glossiness = 0
			sm.specularmap = map
			sampleMaterials[7] = sm
		)

		-- #8: circle
		(
			sm = standardMaterial  showInViewport:true  name:"Circle1"
			sm.diffuse = color 253 253 253
			map = gradient()
			map.coords.U_Tile = false
			map.coords.V_Tile = false
			map.coords.U_Tiling = 1.1
			map.coords.V_Tiling = 1.1
			map.color1 = black
			map.color2 = white
			map.color3 = white
			map.color2Pos = 0.97
			map.gradientType = 1
			sm.opacitymap = map			
			sm.specularlevel	= 0
			sm.glossiness = 0
			sampleMaterials[8] = sm
		)

		-- #9: gradient
		(
			sm = standardMaterial  showInViewport:true  name:"Gradient"
			sm.diffuse = color 253 253 253
			map = gradient()
			map.coords.U_Tile = false
			map.coords.V_Tile = false
			map.coords.U_Tiling = 1.0
			map.coords.V_Tiling = 1.0
			map.color1 = black
			map.color3 = white
			map.gradientType = 0
			sm.opacitymap = map			
			sm.specularlevel	= 0
			sm.glossiness = 0
			sampleMaterials[9] = sm
		)

		-- #10: circle-gradient
		(
			sm = standardMaterial  showInViewport:true  name:"Circle-gradient"
			sm.diffuse = color 253 253 253
			map = gradient()
			map.coords.U_Tile = false
			map.coords.V_Tile = false
			map.coords.U_Tiling = 1.0
			map.coords.V_Tiling = 1.0
			map.color1 = black
-- 			map.color2 = white
			map.color3 = white
			map.color2Pos = 0.5
			map.gradientType = 1
			sm.opacitymap = map			
			sm.specularlevel	= 0
			sm.glossiness = 0
			sampleMaterials[10] = sm
		)

		-- #11: dirt1
		(
			sm = standardMaterial  showInViewport:true  name:"dirt1"
			sm.diffuse = color 253 253 253
			dir = getdir #maxroot + "maps/ground/dry dirt.jpg"
			diffmap = bitmaptexture filename:dir
			sm.diffusemap = diffmap
			map = gradient()
			map.coords.U_Tile = false
			map.coords.V_Tile = false
			map.coords.U_Tiling = 1.0
			map.coords.V_Tiling = 1.0
			map.color2Pos = 0.5
			map.color1 = black
			map.color2 = color 70 70 70
			map.color3 = white
			map.gradientType = 0
			map.noiseAmount = 0.5
			map.noiseType = 1
			map.noiseSize = 1.2
			map.noisePhase = random 0.0 10000.0
			sm.opacitymap = map			
			sm.specularlevel	= 0
			sm.glossiness = 0
			sampleMaterials[11] = sm
		)

		-- #12: dirt2
		(
			sm = standardMaterial  showInViewport:true  name:"dirt2"
			sm.diffuse = color 253 253 253
			dir = getdir #maxroot + "maps/ground/dry dirt.jpg"
			diffmap = bitmaptexture filename:dir
			sm.diffusemap = diffmap
			map = gradient()
			map.coords.U_Tile = false
			map.coords.V_Tile = false
			map.coords.U_Tiling = 1.0
			map.coords.V_Tiling = 1.0
			map.color1 = black
			map.color2 = color 70 70 70
			map.color3 = white
			map.color2Pos = 0.5
			map.gradientType = 1
			map.noiseAmount = 0.5
			map.noiseType = 1
			map.noiseSize = 1.2
			map.noisePhase = random 0.0 10000.0
			sm.opacitymap = map			
			sm.specularlevel	= 0
			sm.glossiness = 0
			sampleMaterials[12] = sm
		)
		
		-- #999: red (for select faces)
		(
			sm = standardMaterial  showInViewport:true  name:"red"
			sm.diffuse = color 255 0 0
			sm.specularlevel	= 0
			sm.glossiness = 0
			sm.opacity = 50
			sampleMaterials[999] = sm
		)
		

		
		selectedMat   matList_dd.selection
		
		-- init ------------------------------------------------------------
		viewport.SetTransparencyLevel 3			-- best  Transparency
		
		-- set TGA io
		Targa.setColorDepth 32
		
		
	)
	
	
	on start_ch changed state do
	(
		if isDeleted DPTargetObj_rollout.obj do
		(
			start_ch.checked = false
			return undefined
		)

		if DPTargetObj_rollout.obj == undefined do
		(
			messagebox "do not pick object"
			start_ch.checked = false
			return undefined
		)
		if superclassof DPTargetObj_rollout.obj != GeometryClass do
		(	
			start_ch.checked = false			
			return undefined
		)
		if classof DPTargetObj_rollout.obj == Biped_Object or classof DPTargetObj_rollout.obj == BoneGeometry do 
		(	
			start_ch.checked = false
			return undefined
		)
		
		if state then
		(
			toolObj = DPTargetObj_rollout.obj
			if toolObj != undefined do
			(
				real_oriObj = toolObj
				smesh = snapshotasMesh DPTargetObj_rollout.obj
				oriObj = mesh mesh:smesh
				DPBake_rollout.SplitVertsByMapVerts  	oriObj			-- split mesh
				
				startTool DPtool
			)
		)
		else
		(
			DPtool.EndTool()
			DPtool.isBtnStop = true
			stopTool DPtool
		)
	)
	

)						-- End...Rectangle















----------------------------------------------- Paint --------------------
fn PaintArea________________________ = ()


fn Linear v0 v1 t =
(
	v0 * (1.0 - t) + v1*t
)


fn getMeshMapCoord  obj   Point2_Veiw = (
	theRay = mapScreenToWorldRay  Point2_Veiw
	theInt = IntersectRayEx obj theRay

	if theInt != undefined do
	(
		theMapFace = meshop.getMapFace obj 1 theInt[2]
		theMapVert1 = meshop.getMapVert obj 1 theMapFace.x
		theMapVert2 = meshop.getMapVert obj 1 theMapFace.y
		theMapVert3 = meshop.getMapVert obj 1 theMapFace.z
		theUVCoords = theMapVert1* theInt[3].x + theMapVert2* theInt[3].y + theMapVert3* theInt[3].z

--		format "%  %\n" mouse.pos  theInt
		#(theInt, theUVCoords)
	)
	
)



--------------------------------------------- mouse Tool ------------
tool dp_PaintTool
(
 	local isBtnStop = false
	local mouseDown = false
	local pos_bak = [0,0,0]
	local ss
	local count = 0
	local isStart = true

	
	fn Csp_Close =
	(
		isBtnStop = true
		
		hide $*
		unhide $tempShape*
		
		allShape = $tempShape* as array
		for sh in allShape do
			sh.material.opacity = 100
		
		$tempCam.orthoProjection = false
		outfile = "c:/temp/test" + DPPaint_rollout.NumStr + ".tga"
		rndMap = render outputwidth:512 outputheight:512  vfb:off  force2sided:false  antiAliasing:false  camera:$tempCam  outputfile:outfile
		
		DPPaint_rollout.pObj.material.diffuse = DPPaint_rollout.col_pick.color
		DPPaint_rollout.pObj.material.selfIllumAmount = 100
		DPPaint_rollout.pObj.material.opacityMap = Bitmaptexture fileName:outfile
		DPPaint_rollout.pObj.material.opacitymap.monoOutput = 1
		DPPaint_rollout.pObj.material.opacityMapAmount = DPPaint_rollout.opacity_spi.value
		DPPaint_rollout.pObj.material.opacityMap.reload()
		
		$tempCam.orthoProjection = true
		unhide $*
			
		delete $tempShape*
		
		DPPaint_rollout.draw_ch.checked = false
		completeRedraw()		

-- 		#stop
-- 		stopTool dp_PaintTool
	)

	
	on mousePoint clickno do			-- clickno: 1 이면 mouseDown 2이면 MouseUp
	(
		if clickno == 1 then
		(
			mouseDown = true
			count = 0
			
			theRay = mapScreenToWorldRay  mouse.pos
			theInt = IntersectRayEx DPPaint_rollout.pObj theRay
			if theInt != undefined do
			(
				pos_bak = [0,0,0]
				
				ss = splineshape pos:theInt[1].pos  dir:DPPaint_rollout.pObj.dir  name:"tempShape"
				addNewSpline ss
				ss.render_renderable = true
				ss.render_displayRenderMesh = true
				ss.render_rectangular = true
				ss.render_length = 0.01
				
				isPer = viewport.IsPerspView()
				if isPer then
					ss.render_width = (length DPPaint_rollout.gPlaneSize) * 0.04 * (20.0 / 50)
				else
					ss.render_width = (length DPPaint_rollout.gPlaneSize) * 0.005 * DPPaint_rollout.size_spi.value
				
				smat = standardMaterial   name:"tempLine_mat"  diffuse:DPPaint_rollout.col_pick.color
				smat.opacity = DPPaint_rollout.opacity_spi.value
				ss.material = smat
				ss.material.selfIllumAmount = 100
				ss.backFaceCull = true
				ss.wirecolor = DPPaint_rollout.col_pick.color
				addmodifier ss (meshselect name:"mesh_sel")
				
				try( updateshape ss )catch()
				
				
				completeRedraw()
			)
		)
		else
		(
 			-- format "mouse Up %\n" clickno
-- 			display TarMap
-- 				

			mouseDown = false
			
			
			gc light:true

			#stop
		)

	)

	on freeMove do
	(
	)
	
	on mouseMove clickno do				-- drag
	(
		if mouseDown  do
		(
			reCoord = getMeshMapCoord  DPPaint_rollout.pObj mouse.pos
			if reCoord != undefined  do
			(
				count +=1
				if reCoord[1] == undefined do return undefined
					
-- 				mapCoord = ([0,-512,0] + (reCoord[2] * [512, 512, 0])) * [1,-1, 1]
--  				print  pos_bak
				penPos = reCoord[1][1].pos

				
				dis = distance penPos pos_bak
				if dis > 0.1 do
				(
					if pos_bak != [0,0,0] and isStart  then
					(
						try( setKnotPoint ss 1 2 penPos )catch()
						isStart = false
					)
					else
					(	
 						if isStart == false do
							try ( addknot ss 1 #smooth #curve  reCoord[1][1].pos  )catch()
					)
					try( updateshape ss )catch()

					pos_bak = penPos
				)
				

				completeRedraw()
				
			)
		)
		
	)
	

	on mouseAbort clickno do
	(
		Csp_Close()
	)
	
	on stop do 
	(
-- 		format "stop % \n" isBtnStop
		
		if isBtnStop == false do
			startTool dp_PaintTool
	)

)






rollout DPPaint_rollout "Paint"
(
	local NumStr = ""
	local pObj							-- dp Plane
	local gPlaneSize
	local decalObj
	
	checkbutton draw_ch "Draw" width:30  height:30 pos:[10, 10] enabled:false
	colorpicker col_pick "" width:25 height:20 pos:[10,52] color:black
	spinner opacity_spi "opa" pos:[55,55]  width:60  scale:10 range:[0,100,100]  type:#integer
	spinner size_spi "size" pos:[130,55]  width:50  scale:1 range:[1,100,2]  type:#integer
	button  makeDecal_btn "CD" width:40 height:22 pos:[130,80]


	
	
	fn tan_  val =
	(
	 tan (radTodeg (val))
	)

	-- 랜더링 할때는 PerspetiveView 로 변환해서 하자
	fn CreatePlaneFromUserView =
	(
		pls = $dpPlane* as array
		
		if $tempCam == undefined  or  pls.count == 0 then
		(
			delete $tempCam*
			cam = freecamera name:"tempCam"
		)
		else
		(
			cam = $tempCam
			
			newPlane = copy pls[pls.count]
			newPlane.transform = transmatrix [0,0,0.01] * newPlane.transform
			DPPaint_rollout.NumStr = (timestamp()) as string
			newPlane.name = ("dpPlane" + DPPaint_rollout.NumStr)
			DPPaint_rollout.pObj = newPlane
			return newPlane
		)
		
		cam.pos = [0,0,500]
		cam.fov = viewport.getFOV()
		cam.orthoProjection = true
		DPPaint_rollout.NumStr = (timestamp()) as string	
		p = plane name:("dpPlane" + DPPaint_rollout.NumStr)  lengthsegs:1  widthsegs:1
		DPPaint_rollout.pObj = p
			

		distFromCamToPlane = 50
		p.pos.z = cam.pos.z - distFromCamToPlane


		planeWidth = (tan_ ((pi / 180.0) * (cam.fov * 0.5))) * distFromCamToPlane
		planeWidth *= 2

	-- 	if displaySafeFrames == false do
	-- 		max safeframe toggle

		renderHeight = 512
		renderWidth = 512
		aspectRatio = renderHeight / (renderWidth as float)
		planeHeight = planeWidth * aspectRatio
		p.width =  planeWidth
		p.length =  planeHeight
-- 		p.parent = cam
		pointA = point pos:p.min name:"tempPoint1"  parent:cam
		pointB = point pos:p.max name:"tempPoint2"  parent:cam
		gPlaneSize = pointB.pos - pointA.pos
		p.parent = cam

		view = inverse (getviewTm())
		cam.transform = view

		gw.setTransform(Matrix3 1)
		s1 = gw.wTransPoint $tempPoint1.pos
		s2 = gw.wTransPoint $tempPoint2.pos
		Psize = s2 - s1
		Psize = [abs Psize.x, abs Psize.y, 0]
		viewSize = getViewSize()
		AspectX = viewSize.x / Psize.x
		AspectY = viewSize.y / Psize.y
		curAspect = 0
		if AspectX < AspectY then
			curAspect = AspectX
		else
			curAspect = AspectY
		
		cam.scale *= curAspect
			
		cam.baseObject.targetDistance = distFromCamToPlane
		delete #(pointA, pointB)

		tarObj = TargetGeometry()
		tarLen = (distance tarObj.max  tarObj.min ) / curAspect
		tdis = (distance cam.pos  p.pos) / curAspect
		cam.transform = transmatrix [0,0, tarLen + tdis] * cam.transform
		
		gPlaneSize *= curAspect
			
		p
	)


	fn CreatePlaneFromPerspetiveView =
	(
		cam = freecamera name:"tempCam"
		cam.pos = [0,0,500]
		cam.fov = 45
		DPPaint_rollout.NumStr = (timestamp()) as string	
		p = plane name:("dpPlane" + DPPaint_rollout.NumStr)    lengthsegs:1  widthsegs:1
		DPPaint_rollout.pObj = p


		distFromCamToPlane = 20
		p.pos.z = cam.pos.z - distFromCamToPlane


		planeWidth = (tan_ ((pi / 180.0) * (cam.fov * 0.5))) * distFromCamToPlane
		planeWidth *= 2

		renderHeight = 512
		renderWidth = 512
		aspectRatio = renderHeight / (renderWidth as float)
		planeHeight = planeWidth * aspectRatio
		p.width =  planeWidth
		p.length =  planeHeight
		p.parent = cam
		pointA = point pos:p.min name:"tempPoint1"  parent:cam
		pointB = point pos:p.max name:"tempPoint2"  parent:cam
		gPlaneSize = pointB.pos - pointA.pos

		view = inverse (getviewTm())
		cam.transform = view
			
		delete #(pointA, pointB)
			
		if displaySafeFrames == false do
			max safeframe toggle
			
			
	-- 	viewport.setCamera cam
		p		
	)
	
	
	
	
	
	fn paintFn =
	(
		
		isPer = viewport.IsPerspView()
		if isPer then									-- perspective
		(
-- 			myPlane = CreatePlaneFromPerspetiveView()
			
			viewport.setType  #view_iso_user
			myPlane = CreatePlaneFromUserView()
		)
		else
		(
			myPlane = CreatePlaneFromUserView()
		)
		
		TargetFilename = sysInfo.tempdir + "dpPlane" + NumStr + ".tga"
		TarMap = bitmap 512 512 color:(color 0 0 0 0)  filename:TargetFilename
		save TarMap
		sm = standardMaterial  showInViewport:true  name:"dpPlane_mat"
		pObj.material = sm
		pObj.material.opacity = 0
		pObj.material.selfIllumAmount = 0
		convertToMesh pObj

		startTool  dp_PaintTool
	)
	
	on draw_ch changed state do 
	(
		if state then
		(
			if TargetGeometry() != undefined do
				paintFn()
		)
		else
		(
			dp_PaintTool.isBtnStop = true
			dp_PaintTool.Csp_Close()
		)
			
	)
	
	
	fn convertSnapMesh obj =
	(
		smesh = snapshotasMesh obj
		delete obj
		decalObj = mesh mesh:smesh
	)
	
	fn addSlice  val =
	(
		myName = "slice" + val as string
		addmodifier  decalObj  (sliceModifier name:myName)
		sc = decalObj.modifiers[myName as name]
	)
	fn setSlice myPlane =
	(
		obj = TargetGeometry()
		if obj == undefined do return undefined
		decalObj = copy obj
		
		decalObj = convertSnapMesh  decalObj

	
		v1 = getvert myPlane 1
		v2 = getvert myPlane 2
		v3 = getvert myPlane 3
		v4 = getvert myPlane 4
		
		left = normalize (v1 - v3)
		front = getFaceNormal myPlane 1
		up = cross left front
	
		offset = v1 - decalObj.pos
		sc1 = addSlice 1
		Tm = matrix3   front  left  up  offset			-- left
		sc1.Slice_Plane = Tm
		sc1.Slice_Type = 2
		
		offset = v2 - decalObj.pos		
		sc2 = addSlice 2
		Tm = matrix3   front  left  up  offset			-- right
		sc2.Slice_Plane = Tm
		sc2.Slice_Type = 3

		offset = v3 - decalObj.pos
		sc3 = addSlice 3
		Tm = matrix3   front  up  left  offset			-- up
		sc3.Slice_Plane = Tm
		sc3.Slice_Type = 3

		offset = v2 - decalObj.pos
		sc4 = addSlice 4
		Tm = matrix3   front  up  left  offset			-- down
		sc4.Slice_Plane = Tm
		sc4.Slice_Type = 2
		


		decalObj = convertSnapMesh  decalObj
		DPBake_rollout.SplitVertsByMapVerts  	decalObj			-- split mesh
		decalObj.name = uniqueName "DecalPlusObj"		

		-- backface culling
		if DPoption_rollout.backface_cb.checked do
		(
			DPBake_rollout.deleteBackface  decalObj
		)


		-- add [push]
		addmodifier decalObj (push name:"dp_push" Push_Value:DpRectangle_rollout.push_spi.value)
		
		-- apply material
		decalObj.material = myPlane.material
		
		-- add [UVWmap]
		if decalObj.modifiers[#dp_CurMap] == undefined do
		(
			select decalObj			-- UVWmap 은 선택해야 함
			max modify mode
			
			addmodifier decalObj (UVWmap name:"dp_CurMap")
			modMap = decalObj.modifiers[#dp_CurMap]
			
			-- gizmo modify [UVWmap]
			offset = myPlane.pos - decalObj.pos
			Tm = matrix3   up  left  front  offset
			modMap.gizmo.transform = Tm
			p_width = distance v1 v2
			modMap.length = p_width
			modMap.width = p_width
		)
		
		decalObj.parent = obj
		
		delete $dpPaint*
		delete $tempCam*
	)
	
	
	
	
	on makeDecal_btn pressed do
	(
		PlaneArray = $dpPlane* as array
		if PlaneArray.count == 0 do return undefined
		
		
		opaList = #()
		comp = compositeTextureMap()
		for i in PlaneArray do
		(
			if comp.maplist[1] == undefined then
				numMap = 1
			else
				numMap = comp.maplist.count + 1
			
			
			comp.maplist[numMap] = Bitmaptexture fileName:i.material.opacitymap.filename
			
			append opaList  i.material.opacityMapAmount
		)
		
		comp.opacity = opaList
		
		
		
		filename= sysInfo.tempdir + "TM_map" + NumStr + ".tga"
		newmap = bitmap 512  512  filename:filename		
		rendermap comp  into:newmap  size:[512,512]  filename:filename
		save newmap
		PlaneArray[1].material.diffusemap = Bitmaptexture fileName:newmap.filename
		PlaneArray[1].material.diffusemap.alphaSource = 2
		PlaneArray[1].material.opacityMap.filename = newmap.filename
		PlaneArray[1].material.opacityMap.monoOutput = 1
		PlaneArray[1].material.opacityMap.reload()
		PlaneArray[1].material.opacityMapAmount = 100
		PlaneArray[1].material.diffuse = white

		-- standard materal 갱신
		PlaneArray[1].material.showinViewport = false
		PlaneArray[1].material.showinViewport = true
		PlaneArray[1].name = "dpPaint"
		
		delPlanes = #()
		for i in 2 to PlaneArray.count do
			append  delPlanes  PlaneArray[i]
		delete delPlanes
		
		
		setSlice PlaneArray[1]
		completeRedraw()
	
		
		gc()		
	)
	
	on DPPaint_rollout close do
	(
		delete $dpPlane*
		delete $dpPaint*
		delete $tempCam*
	)

)



rollout DPetc_rollout  "ETC"
(
	button delAllDecal_btn "Del All Decals" pos:[10,10]
	button undo_btn "Undo" pos:[100,10] width:80  enabled:false
	
	on delAllDecal_btn pressed do
	(
		delete $DecalPlusObj*
		delete $dpLine*
	)
	
	on undo_btn pressed do
	(
	)
)



rollout DPoption_rollout  "Options"
(
	checkbox backface_cb "Delete Back Faces"  checked:true
	checkbox mask_cb "Select Faces to Mask (poly)"
)


















--------- rcmenu ---------------------------
fn rcmenu____________________________ = ()

rcmenu dpRCMENU1
(
	menuItem collapseLayers_me "Collapse Layers" enabled:false
	menuItem collapseLayersAndBase_me "Collapse Layers (include Basemap)" enabled:false
	separator space_se
	menuItem oriTex_me "Baked Texture to Original Texture"  enabled:false
	separator space2_se	
	menuItem text1_me "----------------- Decal ----------------"  enabled:false
	menuItem repose_me "Re-Pose"  enabled:false
	

	--- Not use   (for pasteBitmap)
	fn compfn c1 p1 c2 p2 = 
	(		
		res = c1 + c2 * (1- c1.a/255.0)
		res.a = c1.a + c2.a * (1 - c1.a/255.0)
		res
 	)
	


	on collapseLayers_me picked do
	(
		start = timeStamp()
		
		obj = TargetGeometry()
		if obj == undefined do return undefined
		
-- 		whereMap = undefined
-- 		if DPBake_rollout.whereLayer_dd.selected == "Diffuse Color" then		
-- 			whereMap = obj.material.diffusemap
-- 		else if DPBake_rollout.whereLayer_dd.selected == "Opacity" then
-- 			whereMap = obj.material.opacitymap
		
		whereMap = obj.material.diffusemap
		
		
		if classof whereMap != CompositeTexturemap do return undefined			
		if whereMap.name != "dp_composite" do return undefined
		if whereMap.maplist.count == 1 do return undefined

		texmapArray = for i in 1 to whereMap.maplist.count where i > 1 collect whereMap.maplist[i]
		
		bcount = timestamp()
		filename= sysInfo.tempdir + "TM_map" + bcount as string + ".tga"
		newmap = bitmap texmapArray[1].bitmap.width  texmapArray[1].bitmap.height  filename:filename
		whereMap.mapEnabled[1] = false
		size = [texmapArray[1].bitmap.width, texmapArray[1].bitmap.height]
		rendermap wheremap  into:newmap  size:size filename:filename
		save newmap
		whereMap.mapEnabled[1] = true
		
		whereMap.maplist.count = 2
		whereMap.maplist[2] = bitmaptexture filename:newmap.filename
		
-- 		if DPBake_rollout.whereLayer_dd.selected == "Diffuse Color" then		
-- 			obj.material.diffusemap = whereMap
-- 		else if DPBake_rollout.whereLayer_dd.selected == "Opacity" then
-- 			obj.material.opacitymap = whereMap
		
		-- standard materal 갱신
		obj.material.showinViewport = false
		obj.material.showinViewport = true
		
		gc()

		end = timeStamp()
		format "Processing took % seconds\n" ((end - start) / 1000.0)
		
	)
	
	on collapseLayersAndBase_me picked do
	(
		obj = TargetGeometry()
		if obj == undefined do return undefined
			
-- 		whereMap = undefined
-- 		if DPBake_rollout.whereLayer_dd.selected == "Diffuse Color" then		
-- 			whereMap = obj.material.diffusemap
-- 		else if DPBake_rollout.whereLayer_dd.selected == "Opacity" then
-- 			whereMap = obj.material.opacitymap
		
		whereMap = obj.material.diffusemap

		if classof whereMap != CompositeTexturemap do return undefined
		if whereMap.name != "dp_composite" do return undefined			

		texmapArray = for i in 1 to whereMap.maplist.count collect whereMap.maplist[i]
		
		bcount = timestamp()
		filename= sysInfo.tempdir + "TM_map" + bcount as string + ".tga"
		newmap = bitmap texmapArray[1].bitmap.width  texmapArray[1].bitmap.height  filename:filename
		size = [texmapArray[1].bitmap.width, texmapArray[1].bitmap.height]
		rendermap wheremap  into:newmap  size:size filename:filename
		save newmap
		
		whereMap.maplist.count = 1
		whereMap.maplist[1] = bitmaptexture filename:newmap.filename
		
-- 		if DPBake_rollout.whereLayer_dd.selected == "Diffuse Color" then		
-- 			obj.material.diffusemap = whereMap
-- 		else if DPBake_rollout.whereLayer_dd.selected == "Opacity" then
-- 			obj.material.opacitymap = whereMap
		
		-- standard materal 갱신
		obj.material.showinViewport = false
		obj.material.showinViewport = true
		
		gc()		
	)
	
	
	on oriTex_me  picked do
	(
		SelectMapDialog.setTexMap DPBake_rollout.orignal_mat   SelectMapDialog.selectedMap  oriObj.material.diffusemap
	)

	
	--------[ re-pose ] ------------------------------
	fn reposeFn  baseObj  obj =
	(
		smesh = snapshotasMesh baseObj
		baseMesh = mesh mesh:smesh  name:"dpObject_temp0"

		smesh = snapshotasMesh obj
		objMesh = mesh mesh:smesh  name:"dpObject_temp1"
		
		mapcoordArray = #()
		for v in objMesh.verts do
		(
			p = getvert objMesh  v.index
			n = getnormal objMesh v.index
			myRay = ray p (-n)
			mapcoord = DPBake_rollout.getMeshMapCoord  baseMesh  myRay
			
	-- 		print mapcoord
			if mapcoord == undefined  then
			(
				delete #(baseMesh, objMesh)
				messagebox "failed re-pose"
				return undefined
			)
			append  mapcoordArray  mapcoord[2]
		)
		
		delete #(baseMesh, objMesh)
		mapcoordArray
	)
	
	on repose_me picked do
	(
		obj = TargetGeometry()
		if obj == undefined then return undefined

		DPBake_rollout.reposeArray = reposeFn  oriObj  obj
	)
	
	
	 on dpRCMENU1 open do 
	(
		obj = TargetGeometry()
		if obj == undefined then
		(
			return undefined
		)
		else
		(
			collapseLayers_me.enabled = true
			collapseLayersAndBase_me.enabled = true
			
			sel = DPBake_rollout.getDecalSelect()
			if sel != undefined  do
				repose_me.enabled = true
			
			if obj.material.name == "dp_mtl" do
				oriTex_me.enabled = true
		)
			
		
	)
)






rollout DPBake_rollout  "Bake to Texture"
(
	local  orignal_mat = undefined
 	local  basemap =  undefined
	local  reposeArray = undefined
	
	------------------------- fn --------------------------------------------------
	

	-- bobo fn.....thank you
	fn SplitVertsByMapVerts theMesh =
	(

		--first collect two arrays of bitarrays - one containing the map vertices for each mesh vertex,
		--the other containing the faces using each mesh vertex:
		
-- 		convertToMesh theMesh 
		lastVert = theMesh.numverts
		lastFace = theMesh.numfaces
		VertsUsage = for v = 1 to lastVert collect #{}
		FaceUsage = for v = 1 to lastVert collect #{}
		for f = 1 to lastFace do
		(
			theFace = getFace theMesh f
			theMapFace = meshop.getMapFace theMesh 1 f
			append VertsUsage[theFace.x] theMapFace.x
			append VertsUsage[theFace.y] theMapFace.y
			append VertsUsage[theFace.z] theMapFace.z
			append FaceUsage [theFace.x] f
			append FaceUsage [theFace.y] f
			append FaceUsage [theFace.z] f
		)
		--Now we can go though the mesh vertex array and see if we have 2 or more map vertices.
		--If yes, we count from 2 to the number of map verts and create new mesh vertices with the
		--same position as the current mesh vertex. Then we go through the list of collected faces
		--using that vertex and see which of the 3 components matches the current vertex and its
		--corresponding map vertex matches the current map vertex. We repoint that component of the face
		--to the new mesh vertex. Thus, for each previously existing map vertex, we get a new mesh vertex
		--at the end of the vertex list. 

		for v = 1 to VertsUsage.count do
		(
			theMapVertsArray = VertsUsage[v] as array
			if theMapVertsArray.count > 1 do
			(
				theFacesArray = FaceUsage[v] as array
				theVertPos = getVert theMesh v
				for mapv = 2 to theMapVertsArray.count do
				(
					theMapVert = theMapVertsArray[mapv]
					newIndex = theMesh.numverts+1
					setNumVerts theMesh newIndex true
					setVert theMesh newIndex theVertPos 
					for f in theFacesArray do
					(
						theFaceDef = getFace theMesh f
						theMapFaceDef = meshOp.getMapFace theMesh 1 f
						if theMapFaceDef.x == theMapVert and theFaceDef.x == v do 
						(
							theFaceDef.x = newIndex 
							setFace theMesh f theFaceDef
						)				
						if theMapFaceDef.y == theMapVert and theFaceDef.y == v do 
						(
							theFaceDef.y = newIndex 
							setFace theMesh f theFaceDef
						)				
						if theMapFaceDef.z == theMapVert and theFaceDef.z == v do 
						(
							theFaceDef.z = newIndex 
							setFace theMesh f theFaceDef
						)				
					)--end f loop
				)--end v loop
			)
		)
		update theMesh
	)
	
	
	fn deleteBackface obj =
	(
			----------- delete backfaces --------------------------------------
			backfaces = #{}
			for i in obj.faces do
			(
				in coordsys (inverse (viewport.GetTM())) theFN = getFaceNormal  obj  i.index
				if theFN.z < 0 then append backfaces i.index
			)
			meshop.deleteFaces obj  backfaces
			update obj	
	)


	
	/*            --- not Use (bug??)
	fn getUVcoordFromWorldPos  obj  pos =
	(
		for f in obj.faces do
		(
			re = meshop.getBaryCoords obj  f.index  pos
			if re.x >= -0.0001 and re.y >= -0.0001 and re.z >= -0.0001 do
			(
				-- f is find face
				theMapFace = meshop.getMapFace obj 1 f.index
				theMapVert1 = meshop.getMapVert obj 1 theMapFace.x
				theMapVert2 = meshop.getMapVert obj 1 theMapFace.y
				theMapVert3 = meshop.getMapVert obj 1 theMapFace.z
				theUVCoords = theMapVert1* re.x + theMapVert2* re.y + theMapVert3* re.z
				
				return theUVCoords
			)
		)		
		undefined
	)
	*/
	
	
	fn getUVcoordFromWorldPos  obj  pos  f =
	(
		re = meshop.getBaryCoords obj  f  pos
			-- f is find face
		theMapFace = meshop.getMapFace obj 1 f
		theMapVert1 = meshop.getMapVert obj 1 theMapFace.x
		theMapVert2 = meshop.getMapVert obj 1 theMapFace.y
		theMapVert3 = meshop.getMapVert obj 1 theMapFace.z
		theUVCoords = theMapVert1* re.x + theMapVert2* re.y + theMapVert3* re.z
		
		theUVCoords
	)
	
	
	fn GetCamVFOV  theCamera = 
	( 
		local r_aspect=(renderWidth*renderPixelAspect as float)/renderHeight 
		2.*atan(tan(theCamera.fov/2.)/r_aspect) 
	) 
	
	fn getMeshMapCoord  obj   theRay = (

-- 		theRay = mapScreenToWorldRay  Point2_Veiw
		theInt = IntersectRayEx obj theRay

		if theInt != undefined do
		(
			theMapFace = meshop.getMapFace obj 1 theInt[2]
			theMapVert1 = meshop.getMapVert obj 1 theMapFace.x
			theMapVert2 = meshop.getMapVert obj 1 theMapFace.y
			theMapVert3 = meshop.getMapVert obj 1 theMapFace.z
			theUVCoords = theMapVert1* theInt[3].x + theMapVert2* theInt[3].y + theMapVert3* theInt[3].z

	--		format "%  %\n" mouse.pos  theInt
			#(theInt, theUVCoords)
		)
		
	)
	
	
	fn findNearVert  obj  pos =
	(
		minVal = 10000000
		findVert = 0
		for i in obj.verts do
		(
			dis = distance pos i.pos
			if dis < minVal do
			(
				minVal = dis
				findVert = i.index
			)
		)
		findVert
	)
	
	
	fn deleteEmptyForComposite  &whereMap = 
	(
		while true do
		(
			if keyboard.escPressed do exit
			cnt = 0
			index = 0
			for i in whereMap.maplist do
			(
				index += 1
				if i == undefined do
				(
					cnt += 1
					deleteitem  whereMap.maplist   index
					exit
				)
			)
			if cnt == 0 do exit
		)		
	)
	
	fn getBasemapCount  whereMap =
	(
		if whereMap.name == "dp_composite" and classof whereMap == CompositeTexturemap then
		(
			count = 0
			for i in whereMap.mapList do
			(
				if i != undefined do count += 1
			)
			return count
		)
		else
			return 1
	)
	
	fn getBasemap  &whereMap = 
	(
		if whereMap == undefined  then
			return whereMap
		else if whereMap.name == "dp_composite" and classof whereMap == CompositeTexturemap then
			return whereMap.mapList[1]
		else if classof whereMap == bitmaptexture do
			return whereMap
	)
	
	fn set_composite  baseMap  &whereMap  half_render  = 
	(
		if whereMap.name != "dp_composite" do
		(
			comp = compositeTextureMap()
			comp.mapList[1] = baseMap
			whereMap = comp
			whereMap.name = "dp_composite"
		)
		
		if classof whereMap == CompositeTexturemap do
		(
			-- whereMap.add()		-- 호환성을 위해서 사용하지 말자
			deleteEmptyForComposite  &whereMap
			whereMap.mapList.count = whereMap.mapList.count + 1
			
			whereMap.mapList[whereMap.mapList.count] = bitmaptexture filename:half_render.filename
		)
	)
	
	
	fn bakeToTex  oriObj  obj   mapcoordArray:undefined  =
	(
		if oriObj == undefined do return undefined
		
		-------------------------------------- bake to Texture ------------------------
		if isdeleted obj == false do
		(
			delete $dpObject_*
			
			-------------- delete Lights -------------------
			lightArray = $lights as array
			if lightArray.count > 0 do
			(
				q = queryBox "Delete All Lights?"
				if q then
				(
					delete lightArray
				)
				else
					return undefined
			)
			
			
			smeshObj = copy obj
			convertTomesh obj

			
			
			----------------------
			
			theUVW = smeshObj.modifiers[#dp_CurMap]
			try(  deleteModifier smeshObj theUVW  )catch()
			convertTomesh smeshObj
			
			
			-- #2
			smeshObj2 = copy oriObj
			convertTomesh smeshObj2
			
			-- pre bake ~~~~~~~~~~~~~~~~~~~~~~~~~


			
			

			Obj_mapcoord = #()
			if mapcoordArray == undefined  then
			(
				for v in smeshObj.verts do
				(
					faces = meshop.getFacesUsingVert smeshObj  v.index
					fa = (faces as array)[1]
					uv = getUVcoordFromWorldPos  smeshObj  v.pos  fa
	-- 				format "uv %\n"  uv
					
					-- #2 실패하면 다른 방법으로 다시 시도
					if uv == undefined  then
					(
						p = getvert obj  v.index
						n = getnormal obj v.index
						myRay = ray p (-n)
						mapcoord = getMeshMapCoord  smeshObj2  myRay
						
						if mapcoord == undefined  then
						(	
							delete smeshObj
							delete smeshObj2
							return undefined
						)
						else
						(
	-- 						format "mapcoord %\n"  mapcoord
							append Obj_mapcoord mapcoord[2]
						)
					)
					else
						append Obj_mapcoord  uv
				)
			)
			else															---  [re-pose] --
			(
				Obj_mapcoord = mapcoordArray
			)
-- 			print Obj_mapcoord
			delete smeshObj
			delete smeshObj2

			
			
			---------------------- make texture plane ----------------
			baseObj = plane  length:1 width:1  lengthsegs:1  widthsegs:1 name:"dpObject_baseObj"
			baseObj.pos = [0.5, 0.5, 0]
			
			baseMap = SelectMapDialog.selectedMap
			if oriObj.material.name != "dp_mtl" do
			(
				orignal_mat = oriObj.material
				oriObj.material = standardMaterial showInViewport:true  diffusemap:baseMap  name:"dp_mtl"
			)
			
			if oriObj.material == undefined  or  baseMap == undefined do
			(
				delete $dpObject_*
				return undefined
			)
			
			
			pobj = copy obj
			pobj.name = "dpObject_bakeObj"
			pobj.material = obj.material
			convertToMesh pobj

			for v in pobj.verts do
				setvert pobj  v.index  Obj_mapcoord[v.index]

			
			update pobj
			pobj.pivot = pobj.center
			pobj.parent = baseObj

			-- z 축으로 살짝 올린다
			for v in pobj.verts do
			(
				pos = getvert pobj v.index
				setvert pobj v.index [pos.x, pos.y, 0.005]
			)

			
			if baseMap.bitmap == undefined do
			(
				delete $dpObject_*
				return undefined
			)
				
			renderWidth = baseMap.bitmap.width
			renderHeight = baseMap.bitmap.height
			
			-- 카메라 만들기
			C_camera=Freecamera fov:45 targetDistance:183.3  pos:[0,0,0]  name:"dpObject_cam"
			hfov = C_camera.fov
			vfov = GetCamVFOV  C_camera
			w = 100 * tan(hfov/2)
			l = 100 * tan(vfov/2)
			baseObj.scale.x = 2*w
			baseObj.scale.y = 2*l
			in coordsys C_camera ( baseObj.pos = [0, 0, -100] )
			C_camera.parent = baseObj			--link
			baseObj.pos.z = 0
			

			-------- render ------------------------------------------
			-- bakup Environment
			-- lightLevel : 1.155
			bak_backgroundColor = backgroundColor
			bak_ambientColor = ambientColor
			bak_lightTintColor = lightTintColor
			bak_LightLevel = lightLevel		-- backup LightLevel
			backgroundColor = black
			ambientColor = black
			lightTintColor = white
			lightLevel = 1.155
			
			select #(baseObj, pobj)
			
			-- set render
			if RendererClass.classes[1] == Default_Scanline_Renderer do
			(
				renderers.current = RendererClass.classes[1]()
				renderers.production = RendererClass.classes[1]()
			)
			
			-- set undo
			(
				undofile = sysInfo.tempdir + "TM_undo1.tif"
				undoMap = bitmap baseMap.bitmap.width  basemap.bitmap.height   filename:undofile
				copy basemap.bitmap  undoMap
				save undoMap
			)

			-- visibility
			(
				pobj.visibility = bezier_float()
				pobj.visibility.controller.value = DPBake_rollout.opacity_spi.value
			)
			
			-- 억지로 추가 (나중에 과거 버젼으로 갈수도 있으니 우선 남겨두자)
			hide baseObj
			
			half_render=render camera:C_camera  antiAliasFilterSize:0.1  vfb:false  renderType:#selection  shadows:false  force2sided:true
			
			-- tga 가 가장 정확함
			bcount = timestamp()
			half_render.filename= sysInfo.tempdir + "TM_map" + bcount as string + ".tga"
			print ("save file path:  " + half_render.filename)
			save half_render
			close half_render
			backgroundColor = bak_backgroundColor
			ambientColor = bak_ambientColor
			lightTintColor = bak_lightTintColor
			lightLevel = bak_LightLevel
			
			
			set_composite   baseMap  &oriObj.material.diffusemap  half_render
			
			-- standard materal 갱신
			oriObj.material.showinViewport = false
			oriObj.material.showinViewport = true
			
			delete #(baseObj, pobj, C_camera)
			gc();			freeSceneBitmaps()
			select oriObj
			completeRedraw()
			
			true
		)
		
	)
	


	
	
	timer clock "" interval:500
	button LayerMenu_btn "<" width:30 pos:[145,8]
	dropdownlist  type_dd ""  items:#("Plane", "Normal" ) width:100  pos:[20,35]  visible:false
	checkbox tile_cb "tile"  pos:[10,70]
	spinner rotate_spi "rotate"  Width:100  range:[-10000, 10000, 0]  scale:1
	spinner scale_spi "scale  "  Width:100  range:[0.01, 5, 1]  scale:0.1
	spinner opacity_spi "opacity"  Width:100  range:[0,1,1]
	button bake_btn "Bake"  width:120  height:22  offset:[0,10]
	button iconPic_btn "" width:22 height:22  images:#(DpRectangle_rollout.icon2Fn(), DpRectangle_rollout.icon1aFn(), 1,1,1,1,1 )  enabled:false	


	fn getDecalSelect =
	(
		sels = selection as array
		if sels.count != 1 do return undefined
		if findstring sels[1].name "DecalPlusObj"  == undefined   do return undefined

		sels[1]
	)

	fn set_ui  idx =
	(
		if  idx == 2 then
		(
			tile_cb.visible = true
			rotate_spi.visible = true
			scale_spi.visible = true
			
			tile_cb.pos = [10,70]
			rotate_spi.pos = [150, 70]
			scale_spi.pos = [150,90]
			opacity_spi.pos = [150, 110]
			bake_btn.pos = [40, 140]
			DPBake_rollout.height = 180
			iconPic_btn.pos = [17,bake_btn.pos.y]
		)
		else
		(
			tile_cb.visible = false
			rotate_spi.visible = false
			scale_spi.visible = false
			opacity_spi.pos = [150, 70]
			bake_btn.pos = [40, 100]
			DPBake_rollout.height = 130
			iconPic_btn.pos = [17,bake_btn.pos.y]
		)
	)

	
	fn mapSetting =
	(
		sel = getDecalSelect()
		if sel == undefined  do return undefined
		
		if classof sel.modifiers[1] == Uvwmap do 
		(
			type_dd.selection = 1
			set_ui 1
		)
		if classof sel.modifiers[1] == Uvwunwrap do
		(			
			type_dd.selection = 2
			set_ui 2
		)
		
		if sel.material == undefined do return undefined
		
		texmap = sel.material.opacitymap
		if texmap != undefined do
		(
			tile_cb.checked = texmap.coords.U_Tile
			scale_spi.value = 1/texmap.coords.U_Tiling
		)
		

 		try( opacity_spi.value = sel.visibility.controller.value )catch()
	)
	

	fn clockFn =
	(
		sels = selection as array
		if sels.count == 1 and findstring sels[1].name "DecalPlusObj"  != undefined   then
		(
			bake_btn.enabled = true
			mapSetting()
		)
		else
		(
			bake_btn.enabled = false
		)
	)
	
	
	
	
	on opacity_spi changed val do
	(
		sel = getDecalSelect()
		if sel == undefined  do return undefined

		try( sel.visibility.controller.value = val )catch()
	)
	
	on LayerMenu_btn pressed do
	(
		popupmenu dpRCMENU1
	)
	
	on tile_cb changed val do
	(
		sel = getDecalSelect()
		if sel == undefined  do return undefined
		if sel.material == undefined do return undefined

		texmap = sel.material.opacitymap
		texmap.coords.U_Tile = val
		texmap.coords.V_Tile = val
	)
	
	on rotate_spi changed val do
	(
		sel = getDecalSelect()
		if sel == undefined  do return undefined
		if sel.material == undefined do return undefined

		texmap = sel.material.opacitymap
		texmap.coords.W_Angle = val
	)

	on scale_spi changed val do
	(
		sel = getDecalSelect()
		if sel == undefined  do return undefined
		if sel.material == undefined do return undefined

		texmap = sel.material.opacitymap
		texmap.coords.U_Tiling = 1.0/val
		texmap.coords.V_Tiling = 1.0/val
	)

	
	on clock tick do
	(
		clockFn()
-- 		DpRectangle_rollout.clockFn()
-- 		DpLine_rollout.clockFn()
	)
	
	
	on type_dd  selected  idx do
	(
		set_ui  idx

		sel = getDecalSelect()
		if sel == undefined  do return undefined
		
		if idx == 1 then
		(
			if classof sel.modifiers[1] == Uvwmap do return undefined
			
			theUnwrap = sel.modifiers[#dp_tempUnwrap]
			if theUnwrap != undefined do return undefined
				
			max modify mode			
			theUnwrap = sel.modifiers[#dp_CurMap]
			theUnwrap.name = "dp_tempUnwrap"
			theUnwrap.enabled = false
			bak_Unwrap = theUnwrap
			deleteModifier sel theUnwrap
				
				
			theUVW = sel.modifiers[#dp_tempUVW]
			theUVW.name = "dp_CurMap"
			theUVW.enabled = true
			bak_UVW = theUVW
			deleteModifier sel theUVW
				
			addmodifier  sel  bak_Unwrap
			addmodifier  sel  bak_UVW

		)
		else if idx == 2 do
		(
			theUVW = sel.modifiers[#dp_tempUVW]
			if theUVW != undefined do return undefined
				
			-- type #2
			max modify mode
			
			theUnwrap = sel.modifiers[#dp_tempUnwrap]
			if theUnwrap != undefined do
				deleteModifier sel  theUnwrap
			
			
			theUVW = sel.modifiers[#dp_CurMap]
			theUVW.name = "dp_tempUVW"
			theUVW.enabled = false
			
			addmodifier  sel  (unwrap_uvw name:"dp_CurMap")
			theUnwrap = sel.modifiers[#dp_CurMap]
			subobjectLevel = 3
			theUnwrap.selectFaces #{1..sel.faces.count}
			theUnwrap.setProjectionType  4
			theUnwrap.unwrap5.quickPlanarMap()
			subobjectLevel = 0

		)
	)
	
	on bake_btn pressed do
	(
		sels = selection as array
		
		if sels.count == 1 and findstring sels[1].name "DecalPlusObj"  != undefined   then
		(
			
			if classof sels[1].parent.material != Standardmaterial do 
			(	
				messagebox "No Standardmaterial for parent object"
				return undefined
			)
			
			if sels[1].parent.material == undefined do 
			(	
				messagebox "No Material for parent object"
				return undefined
			)
			
			
			copyObj = copy sels[1]
			
			isResult = undefined
			if reposeArray == undefined  then
				isResult = bakeToTex  copyObj.parent  copyObj
			else
				isResult = bakeToTex  copyObj.parent  copyObj  mapcoordArray:reposeArray
			
			delete copyObj
			if isResult != undefined do
				delete sels[1]
		)
		else
		(
			messagebox "select one Decal object"
		)
	)
	
	on DPBake_rollout open do
	(
		clockFn()
		set_ui  type_dd.selection
		mapSetting()
	)
	
)










-- ###################################################################################-----

try( closeRolloutFloater DpNewFloater )catch()

DpNewFloater = newRolloutFloater "Decal Projector" 200 600
addRollout DpAbout_rollout  DpNewFloater
addRollout DPTargetObj_rollout  DpNewFloater
addRollout DPRectangle_rollout DpNewFloater
-- addRollout DPPaint_rollout  DpNewFloater
addRollout DPetc_rollout  DpNewFloater
addRollout DPoption_rollout  DpNewFloater
addRollout DPBake_rollout DpNewFloater

DpAbout_rollout.open = false
DPetc_rollout.open = false
-- DPRectangle_rollout.open = false








