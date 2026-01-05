// System Routes - Server management endpoints

module.exports = {
  'POST /api/system/shutdown': (params, body) => {
    console.log('Shutdown requested');

    // Send response before shutting down
    setTimeout(() => {
      console.log('Shutting down server...');
      process.exit(0);
    }, 500); // Give time for response to be sent

    return { success: true, message: 'Server shutting down' };
  }
};
