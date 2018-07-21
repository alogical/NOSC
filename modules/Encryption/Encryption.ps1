$OID_SMARTCARD_LOGON       = "1.3.6.1.4.1.311.20.2.2"
$OID_CLIENT_AUTHENTICATION = "1.3.6.1.5.5.7.3.2"
$OID_EMAIL_SIGNATURE       = "1.3.6.1.5.5.7.3.4"

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

function ListPersonalCertificates(){
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

function Decode-Blob {
    param(
        # Data stream for reading a file.
        [System.IO.FileStream]
            $stream,

        # Output buffer.
        [byte[]]
            $buffer
    )
    [int]$count  = 0
    [int]$cursor = 0
    [int]$nbytes = 0

    # Buffer for reading an Int32 blob length preamble.
    [byte[]]$nBuffer = New-Object byte[] 4

    $count   = $stream.Read($nBuffer, 0, 4)
    $cursor += $count

    # Int32 length of the blob.
    $nbytes  = [System.BitConverter]::ToInt32($nBuffer, 0)

    # Will throw an error if the blob is larger than the buffer.
    $count   = $stream.Read($buffer, 0, $nbytes)
    $cursor += $count

    if($count -ne $nbytes){
        throw (New-Object System.FormatException)
    }

    return $count, $cursor
}

function Encode-Int32 {
    param(
        # Data stream for writing a file.
        [Parameter(Mandatory = $true)]
        [System.IO.FileStream]
            $stream,

        # Data to encode.
        [Parameter(Mandatory = $true)]
        [Int32]
            $data
    )
    [int32] $count  = 0
    [byte[]]$buffer = [System.BitConverter]::GetBytes($data)

    $count = $stream.Read($buffer, 0, 4)

    if ($count -ne 4)
    {
        throw (New-Object System.FormatException)
    }

    if ([System.BitConverter]::IsLittleEndian)
    {
        [System.Array]::Reverse($buffer)
    }

    return [System.BitConverter]::ToInt32($buffer, 0)
}

function Decode-Int32 {
    param(
        # Binary data stream.
        [Parameter(Mandatory = $true)]
        [System.IO.FileStream]
            $stream
    )
    [int32] $count  = 0
    [byte[]]$buffer = New-Object byte[] 4

    $count = $stream.Read($buffer, 0, 4)

    if ($count -ne 4)
    {
        throw (New-Object System.FormatException)
    }

    if ([System.BitConverter]::IsLittleEndian)
    {
        [System.Array]::Reverse($buffer)
    }

    return [System.BitConverter]::ToInt32($buffer, 0)
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