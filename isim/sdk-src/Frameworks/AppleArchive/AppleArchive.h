#pragma once
/* isim SDK (self-authored, Apple's declarations): AppleArchive, Apple's archive format and its streams. Adapted
   (frameworks/AppleArchive): headers encoded as "AA01" + fields, entries written and read in that format; compressed
   streams in AppleArchive's block format ("pbz" + the algorithm, blocks compressed with libcompression); extraction to
   and archiving from the app's files. Not in isim: AppleEncryptedArchive (AEA*: encryption and signing). */
#include <AppleArchive/AADefs.h>
#include <AppleArchive/AAByteStream.h>
#include <AppleArchive/AAFieldKeySet.h>
#include <AppleArchive/AAHeader.h>
#include <AppleArchive/AAArchiveStream.h>
#include <AppleArchive/AAPathList.h>
#include <AppleArchive/AAEntryXATBlob.h>
