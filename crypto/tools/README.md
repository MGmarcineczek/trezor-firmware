trezor-crypto tools
===================

Set of small utilities using the trezor-crypto library.

xpubaddrgen
-----------

xpubaddrgen reads job specification from stdin in format:

```
<jobid> <xpub> <change> <from> <to>
```

and prints the results to stdout in format:

```
<jobid> <index> <address>
```

Example input:

```
23 xpub6BcjTvRCYD4VvFQ8whztSXhbNyhS56eTd5P3g9Zvd3zPEeUeL5CUqBYX8NSd1b6Thitr8bZcSnesmXZH7KerMcc4tUkenBShYCtQ1L8ebVe 0 0 5
42 xpub6AT2YrLinU4Be5UWUxMaUz3zTA99CSGvXt1jt2Lgym8PqXbTzmpQ8MHjoLnx8YJiMMUP5iEfR97YQVmgF6B2tAhbCZrXqn65ur526NkZ6ey 1 1000 1005
```

Example output:
```
0x2E23de8D0fBb8229Af44d5cAAd4Fa73Ae24963a8
```

It will print ```<jobid> error``` when there was an error processing job jobid.

It will print ```error``` when it encountered a malformed line.


mktable
-----------

mktable computes the points of the form `(2*j+1)*16^i*G` and prints them in the format to be included in `secp256k1.c` and `nist256p1.c`.
These points are used by the fast ECC multiplication.

It is only meant to be run if the `scalar_mult` algorithm changes.
