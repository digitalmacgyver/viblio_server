===/services/file/download===
Stream an inline media file to the client. The response is HTML with Content-Type set to the mimetype of the media file and Content-Length set to the file size. The response is streamed.

This endpoint can be used as the 'src' attribute in <img> tags for example.

====Parameters====
; id or uuid
:Can specifiy either the media file id or uuid to find. Only media files from the logged in user are searched.

