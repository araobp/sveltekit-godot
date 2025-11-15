extends Node3D
	
func setContent(site, title):
	var image_path = "res://Panels/Images/{site}.jpg".format({"site": site})
	var qr_code_path = "res://Panels/QrCodes/{site}.jpg".format({"site": site})
	setImage(image_path, $Display/Screen, 0, 1.0)
	setImage(qr_code_path, $Info/InfoDisplay/InfoScreenUpper, 0, 0.5)
	setTitle(title)
		
func setImage(res_path, mesh, material_idx, energy):
	var material = StandardMaterial3D.new()
	var image_texture = load(res_path) as CompressedTexture2D
	material.albedo_texture = image_texture	
	material.emission_texture = image_texture
	material.emission_enabled = true
	material.emission_energy_multiplier = energy
	mesh.set_surface_override_material(material_idx, material)
	
func setTitle(text):
	$Info/InfoDisplay/InfoScreenLower/Text.mesh.text = text
	print($Info/InfoDisplay/InfoScreenLower/Text.mesh.text)
