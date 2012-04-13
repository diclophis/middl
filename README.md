# Middle #

The working theory is that for eavy byte read in from a file upload, write that byte to an S3 object.

The hardpart is figuring out howto communicate with S3 in a fashion that allows you to stream the file.

The main problem is that clients are not required to indicate the content size of a file upload, plus multipart parsing is sorta a PITA.
