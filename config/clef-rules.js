function OnSignerStartup(req) {
	console.log("Signer starting up:", JSON.stringify(req, null, 2));
	return { approve: true };
}

function ApproveListing() {
	return "Approve"
}

function ApproveSignData(r) {
	if (r.content_type != 'application/x-clique-header') {
		return 'Reject';
	}
	for (var i = 0; i < r.messages.length; i++) {
		var msg = r.messages[i];
		if (msg.name == 'Clique header' && msg.type == 'clique') {
			var number = parseInt(msg.value.split(' ')[2]);
			var latest = storage.get('lastblock') || 0;
			console.log('number', number, 'latest', latest);
			if (number > latest) {
				storage.put('lastblock', number);
				return 'Approve';
			}
		}
	}
	return 'Reject';
}
