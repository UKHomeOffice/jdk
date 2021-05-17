# Java JDK with SSL

This is a small bootstrap container that allows for custom certificate bundles and CA's  to be added to a mounted volume.
It will then update the certificate stores and the default java keystore.


## Expectations

* /certs - can contain bundle certificates
* /ca - must contain any private trusted CA's you need to trust as individual PEM or CRT files.


