<style type=\"text/css\">
a:hover div {background:#eee;}
#infoWindowSize {max-height:400px; max-width:400px;}
#MarkerInfoWindow a {text-decoration:none;}
#MarkerInfoWindow a:hover { font-weight:800;}

.red_text {color:#ff0000; font-weight:800;}
.green_text {color:#14ba0b; font-weight:800;}
.black_text {color:#000; font-weight:800;} 
.user_list {color:#000}
         
</style>

<script type='text/javascript' src='http://maps.google.com/maps/api/js?%MAP_API_KEY%&sensor=false'></script>
<script type=\"text/javascript\">
var COLORS = [[\"red\", \"#ff0000\"], [\"orange\", \"#ff8800\"], [\"green\",\"#008000\"],
              [\"blue\", \"#000080\"], [\"purple\", \"#800080\"]];
var options = {};
var colorIndex_ = 0;
var map;
var lastPosX;
var lastPosY;
var lastZoom;	    
var clickedPixel; 
var clickedOverlay;
var delCoordX;
var delCoordY;
var markerId;
var PolyInfoWindow = null;
var infowindow = null;
var MapSetCenter = '%MAPSETCENTER%' || '';

function select(buttonId) {
  document.getElementById(\"hand_b\").className=\"unselected\";
  document.getElementById(\"placemark_b\").className=\"unselected\";
  document.getElementById(buttonId).className=\"selected\";
}

function stopEditing() {
  select(\"hand_b\");
}

function getColor(named) {
  return COLORS[(colorIndex_++) % COLORS.length][named ? 0 : 1];
}

function getIcon(color) {
  var icon = new google.maps.MarkerImage(\"/img/google_map/\" + color + \".png\",
      new google.maps.Size(32, 37),
      new google.maps.Point(0,0),
      new google.maps.Point(15, 32));
  return icon;
}


function createMarker(latlng, message, color, title) {

      var Marker = new google.maps.Marker({
      	position: latlng,
      	draggable: false,
      	icon: getIcon(color),
      	map: map,
      	title:title
      });
      
      var contentString = \"\" + message + \"<br/>\";
       
      google.maps.event.addListener(Marker, 'click', function(e) {
	  if (infowindow) {
	  	infowindow.close();
	  }
	     
	  infowindow = new google.maps.InfoWindow({
	     	content: contentString
	  });	  	
	  if (PolyInfoWindow) {
			PolyInfoWindow.close();
	  }

		infowindow.open(map,Marker);
	  });

	  if(title != 'NAS') {
	      google.maps.event.addListener(Marker, 'rightclick', function(e) {
		  if (infowindow) {
		  	infowindow.close();
		  }
		  infowindow = new google.maps.InfoWindow({
		     	content: '<div id=\"MarkerInfoWindow\"><a href=\"index.cgi?index=$index&dcoordx=' + e.latLng.lng() + '&dcoordy='+ e.latLng.lat() + '\">$_DEL_MARKER<\/a></div>'
		  });	  	
		  if (PolyInfoWindow) {
				PolyInfoWindow.close();
		  }
		  	infowindow.open(map,Marker);
		  });	
     }
     return Marker;
}

function initialize() {
    if (MapSetCenter != '') {
       MapSetCenter = MapSetCenter.split(', ');
       myLatlng = new google.maps.LatLng(MapSetCenter[1], MapSetCenter[0]);
       myOptions = {
         zoom: parseInt(MapSetCenter[2]),
         center: myLatlng,
         mapTypeId: google.maps.MapTypeId.ROADMAP,
       }	
	}
	else {
	    myLatlng = new google.maps.LatLng(50.43185060963318, 30.47607421875);
	    myOptions = {
	      zoom: 5,
	      center: myLatlng,
	      mapTypeId: google.maps.MapTypeId.ROADMAP
	    }			
	}
	map = new google.maps.Map(document.getElementById('map'), myOptions);

 	%NAS%
 	%OBJECTS%  
	%ROUTES%
	%WIFI%
	%WELL%
}
function chgposition (x, y , zoom) {
	map.setCenter(new google.maps.LatLng(y, x));
	map.setZoom(zoom);
	lastPosX = x;
	lastPosY = y;
	lastZoom = zoom;	
}
function hideShowDistrict () 
{
	
	if (document.getElementById('districts').style.display == 'none') {
		document.getElementById('districts').style.display = 'block';
		document.getElementById('districtButton').firstChild.nodeValue = '$_HIDE_DISTRICTS';
	} else {
		document.getElementById('districts').style.display = 'none';
		document.getElementById('districtButton').firstChild.nodeValue = '$_SHOW_DISTRICTS';
	}
	if (document.getElementById('districts').style.display == 'none') {		
		
		var height = window.innerHeight;
		var width = window.innerWidth;
		//var height = height  - ((height /100) * 10);
		//var width = width  - ((width /100) * 10);  

		document.getElementById('map').style.width=width+'px';
		document.getElementById('map').style.height=height+ 'px';
		
		if (lastPosX == undefined, lastPosY == undefined, lastZoom == undefined) {
			initialize(%MAPSETCENTER%);
		} else {
			initialize(lastPosX, lastPosY+0.002, lastZoom);
		}
	} else {
		document.getElementById('map').style.width='800px';
		document.getElementById('map').style.height='500px';
		
		if (lastPosX == undefined, lastPosY == undefined, lastZoom == undefined) {
			initialize(%MAPSETCENTER%);
			
		} else {
			initialize(lastPosX, lastPosY, lastZoom);
		}
	}
}

function fullScreenDistrict() {
	var height = window.innerHeight;
	var width = window.innerWidth;
	newWindow = window.open(\"/admin/index.cgi?qindex=$index&header=1\",\"new\", \" 'width=' + width + ',height=' + height \")
	newWindow.focus();
	newWindow.document.getElementById('districtButton').style.display = 'none';
}
google.maps.event.addDomListener(window, 'load', initialize);
</script>
<br />
<a  class='link_button' id=\"districtButton\" onclick=javascript:hideShowDistrict()>$_HIDE_DISTRICTS</a>
<a  class='link_button' id=\"districtButton\" onclick=javascript:fullScreenDistrict()>$_IN_NEW_WINDOW</a>

<table><tr style=\"vertical-align:top\">
  <td style=\"width:15em;\" id=\"districts\" >



    <input type=\"hidden\" id=\"featuredetails\" rows=2>

    </input>

     <table id =\"featuretable\">
     <tbody id=\"featuretbody\"></tbody>
    </table>

    <br />
    <div align=center >%DISTRICTS%  %DELDISTRICT%</div>
     
  </td>
  <td>
    <!-- The frame used to measure the screen size -->
    <div id=\"frame\"></div>

    <div id=\"map\" style=\"width:800px; height:500px\" ></div>
  </td>
</tr></table>