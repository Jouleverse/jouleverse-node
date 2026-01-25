function OnSignerStartup(req) {
	console.log("Signer starting up:", JSON.stringify(req, null, 2));
	return { approve: true };
}

function ApproveListing() {
	return "Approve"
}

function ApproveSignData(req) {
	return "Approve"
}
