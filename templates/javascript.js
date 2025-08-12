<script>

$(function() {
	
	if (document.getElementById("massservicestatus")) {
		interval = window.setInterval(function(){ massservicestatus(); }, 5000);
	}
	massservicestatus();
	getconfig();

});

// MASS SERVICE STATE

function massservicestatus(update) {

	if (update) {
		$("#massservicestatus").attr("style", "background:#dfdfdf").html("<TMPL_VAR "COMMON.HINT_UPDATING">");
		$("#massservicestatusicon").html("<img src='./images/unknown_20.png'>");
	}

	$.ajax( { 
			url:  'ajax.cgi',
			type: 'POST',
			data: { 
				action: 'massservicestatus'
			}
		} )
	.fail(function( data ) {
		console.log( "Servicestatus Fail", data );
		$("#massservicestatus").attr("style", "background:#dfdfdf; color:red").html("<TMPL_VAR "COMMON.HINT_FAILED">");
		$("#massservicestatusicon").html("<img src='./images/unknown_20.png'>");
	})
	.done(function( data ) {
		console.log( "Servicestatus Success", data );
		if (data.pid) {
			$("#massservicestatus").attr("style", "background:#6dac20; color:black").html("<span class='small'>ID: " + data.pid + "</span>");
			$("#massservicestatusicon").html("<img src='./images/check_20.png'>");
		} else {
			$("#massservicestatus").attr("style", "background:#FF6339; color:black").html("<TMPL_VAR "COMMON.HINT_STOPPED">");
			$("#massservicestatusicon").html("<img src='./images/error_20.png'>");
		}
	})
	.always(function( data ) {
		console.log( "Servicestatus Finished", data );
	});
}

// MASS SERVICE RESTART

function massservicerestart() {

	clearInterval(interval);
	$("#massservicestatus").attr("style", "color:blue").html("<TMPL_VAR "COMMON.HINT_EXECUTING">");
	$("#massservicestatusicon").html("<img src='./images/unknown_20.png'>");
	$.ajax( { 
			url:  'ajax.cgi',
			type: 'POST',
			data: { 
				action: 'massservicerestart'
			}
		} )
	.fail(function( data ) {
		console.log( "Servicerestart Fail", data );
	})
	.done(function( data ) {
		console.log( "Servicerestart Success", data );
		if (data == "0") {
			massservicestatus(1);
		} else {
			$("#massservicestatus").attr("style", "background:#dfdfdf; color:red").html("<TMPL_VAR "COMMON.HINT_FAILED">");
		}
		interval = window.setInterval(function(){ massservicestatus(); }, 5000);
	})
	.always(function( data ) {
		console.log( "Servicerestart Finished", data );
	});
}

// MASS SERVICE STOP

function massservicestop() {

	clearInterval(interval);
	$("#massservicestatus").attr("style", "color:blue").html("<TMPL_VAR "COMMON.HINT_EXECUTING">");
	$("#massservicestatusicon").html("<img src='./images/unknown_20.png'>");
	$.ajax( { 
			url:  'ajax.cgi',
			type: 'POST',
			data: { 
				action: 'massservicestop'
			}
		} )
	.fail(function( data ) {
		console.log( "Servicestop Fail", data );
	})
	.done(function( data ) {
		console.log( "Servicestop Success", data );
		if (data == "0") {
			massservicestatus(1);
		} else {
			$("#massservicestatus").attr("style", "background:#dfdfdf; color:red").html("<TMPL_VAR "COMMON.HINT_FAILED">");
		}
		interval = window.setInterval(function(){ massservicestatus(); }, 5000);
	})
	.always(function( data ) {
		console.log( "Servicestop Finished", data );
	});
}

// MASS Open WebUI

function openMASS() {
	window.open( $("#massurl").val(), "_blank" );
}

// PLUGIN GET CONFIG

function getconfig() {

	// Ajax request
	$.ajax({ 
		url:  'ajax.cgi',
		type: 'POST',
		data: {
			action: 'getconfig'
		}
	})
	.fail(function( data ) {
		console.log( "getconfig Fail", data );
	})
	.done(function( data ) {
		console.log( "getconfig Success", data );
		$("#main").css( 'visibility', 'visible' );

		// Settings
	//window.open( location.protocol + '//' + location.hostname + ':' + $("#masshttpport").val(), "_blank" );
		$("#massport").val(data.mass.port);
		if ( data.mass.internal ) {
			$("#massurl").val(location.protocol + '//' + location.hostname + ':8095' );
		} else {
			$("#massurl").val( data.mass.protocol + "://" + data.mass.host + ":" + data.mass.port );
		}
	})
	.always(function( data ) {
		console.log( "getconfig Finished" );
	})

}

// Save SETTINGS (save to config)
/*
function save_settings() {

	$("#savinghint_settings").attr("style", "color:blue").html("<TMPL_VAR "COMMON.HINT_SAVING">");
	$.ajax( { 
			url:  'ajax.cgi',
			type: 'POST',
			data: { 
				action: 'savesettings',
				topic: $("#topic_settings").val(),
				valuecycle: $("#valuescycle_settings").val(),
				statuscycle: $("#statuscycle_settings").val(),
			}
		} )
	.fail(function( data ) {
		console.log( "save_settings Fail", data );
		var jsonresp = JSON.parse(data.responseText);
		$("#savinghint_settings").attr("style", "color:red").html("<TMPL_VAR "COMMON.HINT_SAVING_FAILED">" + " Error: " + jsonresp.error + " (Statuscode: " + data.status + ").");
	})
	.done(function( data ) {
		console.log( "save_settings Done", data );
		if (data.error) {
			$("#savinghint_settings").attr("style", "color:red").html("<TMPL_VAR "COMMON.HINT_SAVING_FAILED">" + " Error: " + data.error + ").");
		} else {
			$("#savinghint_settings").attr("style", "color:green").html("<TMPL_VAR "COMMON.HINT_SAVING_SUCCESS">" + ".");
			getconfig();
		}
	})
	.always(function( data ) {
		console.log( "save_settings Finished", data );
	});

}

// Save SENSORS (save to config)

function save_settings() {

	$("#savinghint_settings").attr("style", "color:blue").html("<TMPL_VAR "COMMON.HINT_SAVING">");
	$.ajax( { 
			url:  'ajax.cgi',
			type: 'POST',
			data: { 
				action: 'savesensors',
				temp_topic: $("#temp_topic").val(),
				humidity_topic: $("#humidity_topic").val(),
				pressure_topic: $("#pressure_topic").val(),
				illuminance_topic: $("#illuminance_topic").val(),
				twilight_topic: $("#twilight_topic").val(),
				solarradiation_topic: $("#solarradiation_topic").val(),
				uv_topic: $("#uv_topic").val(),
				lightning_distance_topic: $("#lightning_distance_topic").val(),
				lightning_last_topic: $("#lightning_last_topic").val(),
				lightning_number_topic: $("#lightning_number_topic").val(),
				windspeed_topic: $("#windspeed_topic").val(),
				winddir_topic: $("#winddir_topic").val(),
				rainstate_topic: $("#rainstate_topic").val(),
				rainrate_topic: $("#rainrate_topic").val(),
				winddir_0_1: $("#winddir_0_1").val(),
				winddir_0_1: $("#winddir_0_2").val(),
				winddir_0_1: $("#winddir_45_1").val(),
				winddir_0_1: $("#winddir45__2").val(),
				winddir_0_1: $("#winddir_90_1").val(),
				winddir_0_1: $("#winddir_90_2").val(),
				winddir_0_1: $("#winddir_135_1").val(),
				winddir_0_1: $("#winddir_135_2").val(),
				winddir_0_1: $("#winddir_180_1").val(),
				winddir_0_1: $("#winddir_180_2").val(),
				winddir_0_1: $("#winddir_225_1").val(),
				winddir_0_1: $("#winddir_225_2").val(),
				winddir_0_1: $("#winddir_270_1").val(),
				winddir_0_1: $("#winddir_270_2").val(),
				winddir_0_1: $("#winddir_315_1").val(),
				winddir_0_1: $("#winddir_315_2").val(),
				pressure_height: $("#pressure_height").val(),
				twilight_max: $("#twilight_max").val(),
				solarradiation_max: $("#solarradiation_max").val(),
				solarradiation_offset: $("#solarradiation_offset").val(),
			}
		} )
	.fail(function( data ) {
		console.log( "save_settings Fail", data );
		var jsonresp = JSON.parse(data.responseText);
		$("#savinghint_sensors").attr("style", "color:red").html("<TMPL_VAR "COMMON.HINT_SAVING_FAILED">" + " Error: " + jsonresp.error + " (Statuscode: " + data.status + ").");
	})
	.done(function( data ) {
		console.log( "save_sensors Done", data );
		if (data.error) {
			$("#savinghint_sensors").attr("style", "color:red").html("<TMPL_VAR "COMMON.HINT_SAVING_FAILED">" + " Error: " + data.error + ").");
		} else {
			$("#savinghint_sensors").attr("style", "color:green").html("<TMPL_VAR "COMMON.HINT_SAVING_SUCCESS">" + ".");
			getconfig();
		}
	})
	.always(function( data ) {
		console.log( "save_sensors Finished", data );
	});

}

*/
</script>
