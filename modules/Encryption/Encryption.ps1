$OID_SMARTCARD_LOGON       = "1.3.6.1.4.1.311.20.2.2"
$OID_CLIENT_AUTHENTICATION = "1.3.6.1.5.5.7.3.2"
$OID_EMAIL_SIGNATURE       = "1.3.6.1.5.5.7.3.4"

###############################################################################
# Encryption Utilities
###############################################################################
<#
.SYNOPSIS
    Encrypts input byte array as a Cryptographic Message Syntax (CMS) envelope.

.LINK
    https://blogs.msdn.microsoft.com/sergey_babkins_blog/2015/11/06/certificates-part-2-encryption-and-decryption-and-some-about-the-cert-store/

.OUTPUT
    Encrypted byte array.
#>
function Encrypt-X509Cms {
    param(
        # Bytes encrypt.
        [Parameter(Mandatory = $true)]
        [Byte[]]
            $Bytes,

        # Certificate to encrypt with public key.
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $Certificate
    )

    $content_info = New-Object System.Security.Cryptography.Pkcs.ContentInfo @($null,$Bytes)
    $envelop      = New-Object System.Security.Cryptography.Pkcs.EnvelopedCms $content_info
    $recipient    = New-Object System.Security.Cryptography.Pkcs.CmsRecipient $Certificate

    $envelop.Encrypt($recipient)

    return $envelop.Encode()
}

<#
.SYNOPSIS
    Decrypt a Cryptographic Message Syntax (CMS) envelope.

.NOTE
    The same certificate with the private key must be already installed
    locally, the decryption will find it by the data in the envelope.

.LINK
    https://blogs.msdn.microsoft.com/sergey_babkins_blog/2015/11/06/certificates-part-2-encryption-and-decryption-and-some-about-the-cert-store/

.OUTPUT
    A decrypted byte array.
#>
function Decrypt-X509Cms {
    param(
        # Bytes decrypt.
        [Parameter(Mandatory = $true)]
        [Byte[]]
            $Bytes,

        # Certificate to decrypt with private key.
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $Certificate
    )

    $envelop = New-Object System.Security.Cryptography.Pkcs.EnvelopedCms
    $envelop.Decode($Bytes)
    $collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection $Certificate
    $envelop.Decrypt($collection)

    return $envelop.ContentInfo.Content
}

<#
.SYNOPSIS
    Encrypts a file on the file system.

.OUTPUT
    [Null]
        Encrypted file is written to file system as name.crypt.
#>
function Encrypt-File {
    param(
        # Path of the file to be encrypted.
        [Parameter(Mandatory = $true)]
        [string]
            $path,

        # X509 certificate used to secure the AES file encryption key.
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $certificate
    )
    # Get FileInfo objects to be encrypted
    $literalPaths = Resolve-Path $path
    $files = New-Object System.Collections.ArrayList
    foreach($p in $literalPaths){
        [void]$files.Add( (Get-Item -LiteralPath $p) )
    }

    # Certificate Data
    #$certificate = Get-CertificateByOid -OID $OID_SMARTCARD_LOGON
    $encode_certificate_thumb  = [System.Text.ASCIIEncoding]::ASCII.GetBytes($certificate.Thumbprint)
    $nbytes_certificate_thumb = [System.BitConverter]::GetBytes($encode_certificate_thumb.Length)

    # Get New AES Encryptor
    $crypto_provider  = New-AesProvider -keysize 256 -blocksize 128
    $nbytes_crypto_iv = [System.BitConverter]::GetBytes($crypto_provider.IV.Length)

    # RSA encrypt crypto key
    $encode_ct_key = Get-KeyExchange -crypto $crypto_provider -cert $certificate
    $nbytes_ct_key = [System.BitConverter]::GetBytes($encode_ct_key.Length)

    # Get encrypted key thumbprint
    $hash_provider = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
    $encode_key_thumb = $hash_provider.ComputeHash($encode_ct_key)
    $nbytes_key_thumb = [System.BitConverter]::GetBytes($encode_key_thumb.Length)

    # Get crypto provider information
    $encode_provider_name   = [System.Text.ASCIIEncoding]::ASCII.GetBytes($crypto_provider.GetType().Name)
    $nbytes_provider_name   = [System.BitConverter]::GetBytes($encode_provider_name.Length)
    $encode_key_size        = [System.BitConverter]::GetBytes($crypto_provider.KeySize)
    $encode_block_size      = [System.BitConverter]::GetBytes($crypto_provider.BlockSize)

    # Write Encrypted File
    $encryptor = $crypto_provider.CreateEncryptor()
    [int]$blocksize = $crypto_provider.BlockSize / 8
    [byte[]]$ptBuffer = @() * $blocksize
    foreach($f in $files){
        $filepath_out = Join-Path (Split-Path $f.FullName -Parent) ((Split-Path $f.FullName -Leaf) + ".crypt" )
        $fstream_in   = [System.IO.BinaryReader]::new( $f.OpenRead() )
        #[System.IO.FileStream]$fstream_in  = $f.OpenRead()

        $fstream_out  = [System.IO.BinaryWriter]::new( [System.IO.File]::Open($filepath_out, [System.IO.FileMode]::Create))
        #[System.IO.FileStream]$fstream_out = New-Object System.IO.FileStream($filepath_out, [System.IO.FileMode]::Create)

        # Write PKI Certificate Info Used for Key Encryption
        $fstream_out.Write( $nbytes_certificate_thumb, 0, 4 )
        $fstream_out.Write( $encode_certificate_thumb, 0, $encode_certificate_thumb.Length )

        # Write Encrypted AES Key Data to File
        $fstream_out.Write( $nbytes_key_thumb, 0, 4)
        $fstream_out.Write( $encode_key_thumb, 0, $encode_key_thumb.Length)

        $fstream_out.Write( $nbytes_provider_name, 0, 4)
        $fstream_out.Write( $encode_provider_name, 0, $encode_provider_name.Length)

        $fstream_out.Write( $encode_key_size, 0, 4)
        $fstream_out.Write( $encode_block_size, 0, 4)

        $fstream_out.Write( $nbytes_crypto_iv, 0, 4 )
        $fstream_out.Write( $crypto_provider.IV, 0, $crypto_provider.IV.Length )

        $fstream_out.Write( $nbytes_ct_key, 0, 4 )
        $fstream_out.Write( $encode_ct_key, 0, $encode_ct_key.Length )

        # Start Encrypt
        [int]$count = 0
        $encipher = New-Object System.Security.Cryptography.CryptoStream($fstream_out, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        Do{
            # Read Block
            $count = $fstream_in.Read($ptBuffer, 0, $blocksize)

            # Encrypt/Write Block
            $encipher.Write($ptBuffer, 0, $count)

        } While ($count -gt 0)

        $fstream_in.Close()
        $encipher.FlushFinalBlock()
        $encipher.Close()
        $fstream_out.Close()

    } # Next File
}

<#
.SYNOPSIS
    Decrypts a file on the file system.

.OUTPUT
    [Null]
        Decrypted file is written to file system as name.ext
#>
function Decrypt-File {
    param(
        # Path expression of files to decrypt.
        [Parameter(Mandatory = $true)]
        [string]
            $path
    )
    $literalPaths = Resolve-Path $path
    $files = New-Object System.Collections.ArrayList
    foreach($p in $literalPaths){
        [void]$files.Add( (Get-Item -LiteralPath $p) )
    }

    $certificates = @{}
    $decryptors   = @{}
    [string]$certificateThumb = [string]::Empty
    [string]$keyThumb         = [string]::Empty
    [byte[]]$buffer = New-Object byte[] 512         # large enough to contain an encrypted 256 AES Key
    [int]$count  = 0
    [int]$nbytes = 0
    [int]$cursor = 0
    foreach($f in $files){
        [System.IO.FileStream]$fstream_in = $f.OpenRead()

        # Read Certificate Used for Encryption
        $count, $cursor = Decode-Blob $fstream_in $buffer
        $certificateThumb = ([System.Text.ASCIIEncoding]::ASCII.GetChars($buffer, 0, $count) -join '')

        $buffer.Clear()

        # Read Key Thumbprint
        $count, $cursor = Decode-Blob $fstream_in $buffer
        $keyThumb = [System.Text.ASCIIEncoding]::ASCII.GetChars($buffer, 0, $count) -join ''

        $buffer.Clear()

        # Read Key Initialization Vector
        $count, $cursor = Decode-Blob $fstream_in $buffer
        [byte[]]$keyIV = New-Object byte[] $count
        [System.Array]::Copy($buffer, $keyIV, $count)

        $buffer.Clear()

        # Read Encrypted Key Blob
        $count, $cursor = Decode-Blob $fstream_in $buffer
        [byte[]]$ctKeyblob = New-Object byte[] $count
        [System.Array]::Copy($buffer, $ctKeyblob, $count)

        $buffer.Clear()

        # Retrieve the Certificate for Decrypting the Key
        if ($certificates.ContainsKey($certificateThumb))
        {
            $cert = $certificates[$certificateThumb]
        }
        else
        {
            $cert = Retrieve-Certificate -Thumbprint $certificateThumb
            $certificates.Add($certificateThumb, $cert)
        }

        # Decrypt AES Key
        if ($decryptors.ContainsKey($keyThumb))
        {
            $decryptor = $decryptors[$keyThumb]
        }
        else
        {
            $ptKeyblob = Decrypt-RSA -blob $ctKeyblob -cert $cert -OAEP $false

            $aes = New-AesProvider 256 128
            $decryptor = $aes.CreateDecryptor($ptKeyblob, $keyIV)

            # Zeroize plain text key blob
            for ($i = 0; $i -lt $ptKeyblob.Length; $i++)
            {
                $ptKeyblob[$i] = $null
            }

            $decryptors.Add($keyThumb, $decryptor)
        }

        # Decrypt File
        $pathout = Join-Path (Split-Path $f.FullName -Parent) (Split-Path $f.FullName -Leaf).Replace('.crypt', '')
        $fstream_out = New-Object System.IO.FileStream($pathout, [System.IO.FileMode]::Create)

        $count = 0
        [int]$blocksize = $aes.BlockSize / 8
        [byte[]]$ctBuffer = New-Object byte[] $blocksize
        $decipher = New-Object System.Security.Cryptography.CryptoStream($fstream_out, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        Do {
            $count = $fstream_in.Read($ctBuffer, 0, $blocksize)
            $decipher.Write($ctBuffer, 0, $count)
        } While ($count -gt 0)
        $fstream_in.Close()
        $decipher.FlushFinalBlock()
        $decipher.Close()
        $fstream_out.Close()
    } # Next File
}

<#
.SYNOPSIS
    Performs RSA encryption on a blob of data using a digital certificate's public key.

.OUTPUT
    [Byte[]]
        Encrypted byte array of data blob.
#>
function Encrypt-RSA {
    param(
        # Data to be encrypted.
        [Parameter(Mandatory = $true)]
        [byte[]]
            $blob,

        # X509 Certificate for RSA encryption.
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $cert,

        [Parameter(Mandatory = $false)]
        [bool]
            $OAEP
    )
    $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]$cert.PublicKey.Key
    return $rsa.Encrypt($blob, $OAEP)
}

<#
.SYNOPSIS
    Performs RSA decryption on a blob of data using a digital certificate's private key.

.NOTE
    Vendor drivers/software must be installed for certificates stored on a
    Common Access Card (CAC).

.OUTPUT
    [Byte[]]
        Decrypted byte array of data blob.
#>
function Decrypt-RSA {
    param(
        # Data to be decrypted.
        [Parameter(Mandatory = $true)]
        [byte[]]
            $blob,

        # X509 Certificate for RSA decryption.
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $cert,

        [Parameter(Mandatory = $false)]
        [bool]
            $OAEP
    )
    $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]$cert.PrivateKey
    return $rsa.Decrypt($blob, $OAEP)
}

<#
.SYNOPSIS
    Generate an RSA signature from data blob.

.NOTE
    Used to digitally sign encrypted AES keys used for file encryption in order
    to validate the key before decryption.

.OUTPUT
    Boolean:
        Signature validation.
#>
function Sign-Message {
    param(
        [byte[]]
            $blob,

        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $cert
    )
    throw (New-Object System.NotImplementedException)
}

###############################################################################
# Encryption Basic Support Utilities
###############################################################################

<#
.SYNOPSIS
    Generates an encrypted key exchange for an symmetric encryption algorithm.

.OUTPUT
    [Byte[]]
        Encrypted byte array of the symmetric algorithm encryption key.
#>
function Get-KeyExchange {
    param(
        # Crypto provider object.
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.SymmetricAlgorithm]
            $crypto,

        # X509 Certificate for key exchange RSA encryption.
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $cert
    )
    $rsa     = [System.Security.Cryptography.RSACryptoServiceProvider]$cert.PublicKey.Key
    $encoder = [System.Security.Cryptography.RSAPKCS1KeyExchangeFormatter]::new($rsa)
    return $encoder.CreateKeyExchange($crypto.Key, $aes.GetType())
}

<#
.SYNOPSIS
    Creates a new AES encryption provider object.

.OUTPUT
    [System.Security.Cryptography.AesCryptoServiceProvider]
#>
function New-AesProvider {
    param(
        # 32bit key length.
        [Parameter(Mandatory = $false)]
        [int]
            $keysize = 256,

        [Parameter(Mandatory = $false)]
        [int]
            $blocksize = 128,

        [Parameter(Mandatory = $false)]
        [System.Security.Cryptography.CipherMode]
            $mode = [System.Security.Cryptography.CipherMode]::CBC
    )
    $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider

    # max = 256
    $aes.KeySize = $keysize

    # max = 128
    $aes.BlockSize = $blocksize

    #region # Avaliable Cipher Modes
    # Default CBC
    # -----------
    # The Cipher Block Chaining (CBC) mode introduces feedback. Before each plain text block is encrypted, it
    # is combined with the cipher text of the previous block by a bitwise exclusive OR operation. This ensures
    # that even if the plain text contains many identical blocks, they will each encrypt to a different cipher
    # text block. The initialization vector is combined with the first plain text block by a bitwise exclusive
    # OR operation before the block is encrypted. If a single bit of the cipher text block is mangled, the
    # corresponding plain text block will also be mangled. In addition, a bit in the subsequent block, in the
    # same position as the original mangled bit, will be mangled.
    #
    # The Cipher Feedback (CFB) mode processes small increments of plain text into cipher text, instead of
    # processing an entire block at a time. This mode uses a shift register that is one block in length and is
    # divided into sections. For example, if the block size is 8 bytes, with one byte processed at a time, the
    # shift register is divided into eight sections. If a bit in the cipher text is mangled, one plain text bit
    # is mangled and the shift register is corrupted. This results in the next several plain text increments being
    # mangled until the bad bit is shifted out of the shift register. The default feedback size can vary by algorithm,
    # but is typically either 8 bits or the number of bits of the block size. You can alter the number of feedback
    # bits by using the FeedbackSize property. Algorithms that support CFB use this property to set the feedback.
    #
    # The Cipher Text Stealing (CTS) mode handles any length of plain text and produces cipher text whose length
    # matches the plain text length. This mode behaves like the CBC mode for all but the last two blocks of the plain
    # text.
    #
    # The Electronic Codebook (ECB) mode encrypts each block individually. Any blocks of plain text that are identical
    # and in the same message, or that are in a different message encrypted with the same key, will be transformed into
    # identical cipher text blocks. Important:  This mode is not recommended because it opens the door for multiple security
    # exploits. If the plain text to be encrypted contains substantial repetition, it is feasible for the cipher text to be
    # broken one block at a time. It is also possible to use block analysis to determine the encryption key. Also, an active
    # adversary can substitute and exchange individual blocks without detection, which allows blocks to be saved and inserted
    # into the stream at other points without detection.
    #
    # The Output Feedback (OFB) mode processes small increments of plain text into cipher text instead of processing an
    # entire block at a time. This mode is similar to CFB; the only difference between the two modes is the way that the
    # shift register is filled. If a bit in the cipher text is mangled, the corresponding bit of plain text will be mangled.
    # However, if there are extra or missing bits from the cipher text, the plain text will be mangled from that point on.
    #endregion
    if ($mode -eq [System.Security.Cryptography.CipherMode]::ECB)
    {
        throw (New-Object System.ArgumentException("CipherMode ECB is unsecure and not supported."))
    }
    $aes.Mode = $mode

    return $aes
}

###############################################################################
# Certificate Management
###############################################################################
<#
.SYNOPSIS
    Prints formated output of the cert:\CurrentUser\My certificate store.

.OUTPUT
    [Null]
#>
function List-Certificates(){
    $personalStore = Get-ChildItem Cert:\CurrentUser\My
    foreach($certificate in $personalStore){
        Write-Host ("/" * 80) -ForegroundColor Cyan
        Write-Host $certificate.FriendlyName -ForegroundColor Magenta
        Write-Host ($certificate.NotBefore.ToString() + " to " + $certificate.NotAfter.ToString()) -ForegroundColor Magenta
        foreach($usage in $certificate.EnhancedKeyUsageList){
            Write-Host $usage
        }
        ''
    }
}

<#
.SYNOPSIS
    Retrieves a first personal certificate matching a specified usage Oid.

.NOTE
    Oid - Object Identifier: a string ID that specifies the accepted usage for
    a certificate. E.g. signing, encryption, etc...

.OUTPUT
    [System.Security.Cryptography.X509Certificates.X509Certificate2]
#>
function Get-CertificateByOid {
    param(
        [Parameter(Mandatory = $true)]
        [string]
            $oid
    )
    $personalStore = Get-ChildItem Cert:\CurrentUser\My
    foreach($certificate in $personalStore){
        foreach($usage in $certificate.EnhancedKeyUsageList){
            if($usage.ObjectId -eq $oid){
                return $certificate
            }
        }
    }
    return $null
}

<#
.SYNOPSIS
    Retrieves a certificate from the cert:\CurrentUser\My certificate store.

.OUTPUT
    [System.Security.Cryptography.X509Certificates.X509Certificate2]
#>
function Retrieve-Certificate {
    [Cmdletbinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Thumb")]
        [string]
            $Thumbprint,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Name")]
        [string]
            $Name,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Name")]
        [string]
            $SerialNumber
    )

    if ($PSCmdlet.ParameterSetName -eq "Thumb")
    {
        return (Get-Item "Cert:\CurrentUser\My\$Thumbprint")
    }

    if ($PSCmdlet.ParameterSetName -eq "Name")
    {
        $personalStore = Get-ChildItem Cert:\CurrentUser\My
        foreach($certificate in $personalStore){
            if($certificate.FriendlyName -eq $Name -and $certificate.SerialNumber -eq $SerialNumber){
                return $certificate
            }
        }
        return $null
    }
}

<#
.SYNOPSIS
    Generates a self-signed certificate.

.LINK
    https://blogs.msdn.microsoft.com/sergey_babkins_blog/2015/11/06/certificates-part-2-encryption-and-decryption-and-some-about-the-cert-store/
    https://msdn.microsoft.com/en-us/library/bfsktky3(VS.100).aspx

.OUTPUT
    PKCS#7 public key export to file system.
#>
function New-Certificate {
    param(
        [Parameter(Madatory = $true)]
        [string]
            $name
    )
    # Exportable Private Key
    #makecert.exe -r -pe -a sha512 -n "CN=$name" -ss My -sr CurrentUser -len 2048 -sky exchange -sp "Microsoft Enhanced RSA and AES Cryptographic Provider" -sy 24 "$name.cer"

    makecert.exe -r -a sha512 -n "CN=$name" -ss My -sr CurrentUser -len 2048 -sky exchange -sp "Microsoft Enhanced RSA and AES Cryptographic Provider" -sy 24 "$name.cer"
}

###############################################################################
# Buffer - Byte Array Binary Data Blob Utilities
###############################################################################
<#
.SYNOPSIS
    Write an binary data blob to byte array buffer.

.OUTPUT
    [Int32]
        Count - number of bytes written to buffer.
#>
function Write-BlobB {
    param(
        # Data to be written.
        [byte[]]
            $blob,

        # Byte[] buffer to be written to.
        [byte[]]
            $buffer,

        # Position within the buffer to start writing at.
        [int32]
            $index
    )
    # Bounds check - preamble + blob must fit in buffer.
    if ($buffer.Length - ($index + 4) -lt $blob.Length)
    {
        throw (New-Object System.IndexOutOfRangeException("Destination buffer is to small."))
    }

    # Write length of the blob.
    Encode-Int32B -buffer $buffer -data $blob.Length

    # Write the blob data.
    [System.Array]::Copy($blob, 0, $buffer, $index + 4, $blob.Length)

    #Count of bytes written.
    return ($blob.Length + 4)
}

<#
.SYNOPSIS
    Read an binary data blob from a byte array buffer.

.NOTE
    Data blob is copied into the [byte[]] output buffer, and length of the
    blob is stored in the returned count integer.

.OUTPUT
    [Int32]
        Count  - number of bytes read from the blob buffer.
#>
function Read-BlobB {
    param(
        # Byte array data blob.
        [byte[]]
            $blob,

        # Start position in blob byte array.
        [int32]
            $index,

        # Output buffer.
        [byte[]]
            $buffer
    )
    [int]$nbytes = 0

    # Buffer for reading an Int32 blob length preamble.
    $nbytes = Decode-Int32B -buffer $blob -index $index

    # throw an error if the input blob array isn't the right length.
    if ($blob.Length - ($index + 4) -lt $nbytes)
    {
        throw (New-Object System.IndexOutOfRangeException("Source buffer is smaller than the expected blob size [$nbytes] bytes."))
    }

    # throw an error if the blob is larger than the buffer.
    if ($buffer.Length -lt $nbytes)
    {
        throw (New-Object System.IndexOutOfRangeException("Destination buffer is to small to hold $nbytes bytes of data."))
    }
    [System.Array]::Copy($blob, $index + 4, $buffer, 0, $nbytes)

    return $nbytes
}

<#
.SYNOPSIS
    Encodes a string as an ASCII byte blob into byte array buffer.

.OUTPUT
    [Int32]
        Count - number of bytes written to the buffer.
#>
function Encode-AsciiB {
    param(
        # Data to encode.
        [Parameter(Mandatory = $true)]
        [String]
            $data,

        # Byte buffer to be written to.
        [Parameter(Mandatory = $true)]
        [Byte[]]
            $buffer,

        # Index of buffer to start writing at.
        [Parameter(Mandatory = $true)]
        [Int32]
            $index
    )
    $bytes = [System.Text.ASCIIEncoding]::ASCII.GetBytes($data)

    # buffer bounds check - must be large enough to hold data blob.
    if ($buffer.Length - (4 + $index + $bytes.Length) -lt 0)
    {
        throw (New-Object System.IndexOutOfRangeException("Destination buffer is to small."))
    }
    $index += Encode-Int32B -data $bytes.Length -buffer $buffer -index $index
    [System.Array]::Copy($bytes, 0, $buffer, $index, $bytes.Length)

    return (4 + $bytes.Length)
}

<#
.SYNOPSIS
    Decodes an ASCII string blob from a byte array buffer.

.OUTPUT
    [String] UTF8
        The decoded string converted to the default UTF8 format used by
        PowerShell.
#>
function Decode-AsciiB {
    param(
        # Binary data byte array buffer.
        [Parameter(Mandatory = $true)]
        [Byte[]]
            $buffer,

        # The index from which to start reading from the buffer.
        [Parameter(Mandatory = $true)]
        [Int32]
            $index
    )
    # 4 byte - blob length field
    $nbytes = Decode-Int32B -buffer $buffer -index $index

    # n byte - variable length blob data bounds check
    if ($buffer.Length - (4 + $nbytes) -lt $nbytes)
    {
        throw (New-Object System.IndexOutOfRangeException("Source buffer is smaller than the expected Ascii blob size [$nbytes] bytes."))
    }

    # return ascii string converted to PowerShell UTF8 format.
    return [System.Text.UnicodeEncoding]::UTF8.GetString($buffer, $index + 4, $nbytes)
}

<#
.SYNOPSIS
    Encodes an [Int32] value into a byte array buffer.

.NOTE
    Integers are encoded in Network Byte Order (Big Endian) within the binary
    data stream.

.NOTE
    4 bytes will always be written to the buffer.

.OUTPUT
    [Null]
#>
function Encode-Int32B {
    param(
        # Data to encode.
        [Parameter(Mandatory = $true)]
        [Int32]
            $data,

        # Byte buffer to be written to.
        [Parameter(Mandatory = $true)]
        [Byte[]]
            $buffer,

        # Index of buffer to start writing at.
        [Parameter(Mandatory = $true)]
        [Byte[]]
            $index
    )
    # 4 bytes must be available in buffer.
    if ($buffer.Length - $index -lt 4)
    {
        throw (New-Object System.IndexOutOfRangeException("Destination buffer is to small from index [$index] to contain the 4 byte integer."))
    }

    [byte[]]$bytes = [System.BitConverter]::GetBytes($data)

    # Convert to Network Byte Order
    if ([System.BitConverter]::IsLittleEndian)
    {
        [System.Array]::Reverse($bytes)
    }
    [System.Array]::Copy($bytes, 0, $buffer, 0, 4)
    return 4 #Int32 byte count
}

<#
.SYNOPSIS
    Decodes an [Int32] value from a byte array buffer.

.NOTE
    Integers are encoded in Network Byte Order (Big Endian) within the binary
    data stream.

.NOTE
    4 bytes will always be read from buffer.

.OUTPUT
    [Int32]
        The integer value decoded from the buffer.
#>
function Decode-Int32B {
    param(
        # Binary data byte array buffer.
        [Parameter(Mandatory = $true)]
        [Byte[]]
            $buffer,

        # The index from which to start reading from the buffer.
        [Parameter(Mandatory = $true)]
        [Int32]
            $index
    )
    # 4 bytes must be readable
    if ($buffer.Length - $index -lt 4)
    {
        throw (New-Object System.IndexOutOfRangeException)
    }
    [byte[]]$bytes = New-Object byte[] 4
    [System.Array]::Copy($buffer, $index, $bytes, 0, 4)

    # Convert from Network Byte Order
    if ([System.BitConverter]::IsLittleEndian)
    {
        [System.Array]::Reverse($bytes)
    }

    return [System.BitConverter]::ToInt32($bytes, 0)
}

###############################################################################
# Stream  - Binary Data Blob Utilities
###############################################################################
<#
.SYNOPSIS
    Write an binary data blob within binary data stream.

.OUTPUT
    [Int32]
        Count - number of bytes written to the binary data stream.
#>
function Write-BlobS {
    param(
        # Data stream for reading a file.
        [System.IO.BinaryWriter]
            $stream,

        # Data blob.
        [byte[]]
            $blob
    )
    [int]$count  = 0
    [int]$nbytes = 0

    # Write length of the blob.
    Encode-Int32 -data $blob.Length -stream $stream

    # Write the blob data.
    $stream.Write($blob, 0, $blob.Length)

    #Count of bytes written to stream.
    return ($blob.Length + 4)
}

<#
.SYNOPSIS
    Read an binary data blob from a binary data stream.

.NOTE
    Data blob is copied into the [byte[]] buffer, and length of the
    blob is stored in the returned count integer.

.OUTPUT
    [Int32]
        Count - number of bytes read into the byte array buffer.
#>
function Read-BlobS {
    param(
        # Data stream for reading a file.
        [System.IO.BinaryReader]
            $stream,

        # Output buffer.
        [byte[]]
            $buffer
    )
    [int]$count  = 0
    [int]$nbytes = 0

    # Buffer for reading an Int32 blob length preamble.
    $nbytes = Decode-Int32S -stream $stream

    # Will throw an error if the blob is larger than the buffer.
    $count = $stream.Read($buffer, 0, $nbytes)

    # Thow error if stream ended before the entire blob was read.
    if($count -ne $nbytes){
        throw (New-Object System.FormatException)
    }

    # count of bytes written to byte[] buffer
    return $count
}

<#
.SYNOPSIS
    Encodes a string as ASCII bytes within a binary data stream.

.OUTPUT
    [Int32]
        Count - number of bytes written to the binary data stream.
#>
function Encode-AsciiS {
    param(
        # Data to encode.
        [Parameter(Mandatory = $true)]
        [String]
            $data,

        # Byte buffer to be written to.
        [Parameter(Mandatory = $true)]
        [System.IO.BinaryWriter]
            $stream
    )
    $bytes = [System.Text.ASCIIEncoding]::ASCII.GetBytes($data)
    Encode-Int32S -data $bytes.Length -stream $stream

    $stream.Write($bytes, 0, $bytes.Length)
}

<#
.SYNOPSIS
    Decodes an ASCII string from a binary data stream.

.OUTPUT
    [String] UTF8
        The decoded string converted to the default UTF8 format used by
        PowerShell.
#>
function Decode-AsciiS {
    param(
        # Binary data stream.
        [Parameter(Mandatory = $true)]
        [System.IO.BinaryReader]
            $stream
    )
    $nbytes = Decode-Int32S $stream
    $bytes  = New-Object Byte[] $nbytes

    # throw error if the stream ended before the entire blob was read.
    $count = $stream.Read($bytes, 0, $nbytes)
    if ($count -ne $nbytes)
    {
        throw (New-Object System.FormatException)
    }

    # return ascii string converted to PowerShell UTF8 format.
    return [System.Text.UnicodeEncoding]::UTF8.GetString($bytes)
}

<#
.SYNOPSIS
    Encodes an [Int32] value into a binary data stream.

.NOTE
    Integers are encoded in Network Byte Order (Big Endian) within the binary
    data stream.

.NOTE
    The binary data stream cursor will always be advanced by 4 bytes.

.OUTPUT
    [Null]
#>
function Encode-Int32S {
    param(
        # Data to encode.
        [Parameter(Mandatory = $true)]
        [Int32]
            $data,

        # Data stream for writing a file.
        [Parameter(Mandatory = $true)]
        [System.IO.BinaryWriter]
            $stream
    )
    [byte[]]$bytes = [System.BitConverter]::GetBytes($data)
    if ([System.BitConverter]::IsLittleEndian)
    {
        [System.Array]::Reverse($bytes)
    }
    $stream.Write($bytes, 0, 4)
}

<#
.SYNOPSIS
    Decodes an [Int32] value from a binary data stream.

.NOTE
    Integers are encoded in Network Byte Order (Big Endian) within the binary
    data stream.

.NOTE
    The binary data stream cursor will always be advanced by 4 bytes.

.OUTPUT
    [Int32]
        The integer value decoded from the data stream.
#>
function Decode-Int32S {
    param(
        # Binary data stream.
        [Parameter(Mandatory = $true)]
        [System.IO.BinaryReader]
            $stream
    )
    [int32] $count = 0
    [byte[]]$bytes = New-Object byte[] 4

    $count = $stream.Read($bytes, 0, 4)

    if ($count -ne 4)
    {
        throw (New-Object System.FormatException)
    }

    if ([System.BitConverter]::IsLittleEndian)
    {
        [System.Array]::Reverse($bytes)
    }

    return [System.BitConverter]::ToInt32($bytes, 0)
}
