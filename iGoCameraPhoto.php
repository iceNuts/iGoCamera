<?php
	
	if($_FILES['photo']['size'] <= 0)
		exit("null");
	
	$uploadFileDir = $_SERVER['DOCUMENT_ROOT'].'/iGoPhotos/';
	if(!is_dir($uploadFileDir)){
		mkdir($uploadFileDir);
	}
	
	$filePath = $uploadFileDir.$_FILES['photo']['name'];
	
	move_uploaded_file($_FILES['photo']['tmp_name'], $filePath);
	
	$wsdl = "http://erpws.59igou.com/FileService.asmx?wsdl";
		$client = new SoapClient($wsdl);
		
	$pos = strpos($_FILES['photo']['name'], '&', 0);
	
	$params = array(
		'FileName' => $_FILES['photo']['name'],
		'Conno' => substr($_FILES['photo']['name'], 0, $pos),
		'sn' => substr(substr($_FILES['photo']['name'], 0, strlen($_FILES['photo']['name']) - 10), $pos+1),
	);
	
	$response = $client->GET_NEW_FILE($params);
	