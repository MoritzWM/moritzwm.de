{ config, pkgs, ... }:
{
  users.users.moritz = {
    isNormalUser = true;
    home = "/home/moritz";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAuTjHw/LFq2JW9YlpZJSreTXUqTOoDhBRLni2G0jqsd7vTbSpbUektk9o4OnV1PUYuKXCa9Z/PYjf/VQF8uthb1zF9FSKDL8mlB/u8QYy+6n2aNQh+/ZFQ10Hq0sI3DiggYiNjb77AU04W19N7KgZlTAOjMVL5+gsEV13u4PNs/otqg4ID3yhHj5WiKUkiv910SAfHiwnJcwI0MUQYIz80eUM5vsMitaB57fFUE/jVIgfy0i7mt6Fvbx5lqhRrSXaW48cd87CvU8HNO6D5dwlvqTKs1nKTWbRNqDnSR9mGtnaKVWnaeMByMdvovpdn3na8Yw2uIrK187hLxeNTHZDB6TqjprZVearRG1Aw8/HTYeJwb7B0XvKn9LCSCWFtuFP52TVK8+YfLAwXOs5Q+D6x1qzwRXmRV697P5tADrD/UGnBAKk7xGwy3ocqcSq6ap+aloGhQ54lnRSyPBGtgSzRbSodHx9TTMhgHfvIMasEI+7+Kxzuhc0LBDJCTK/bFN4ySgfzIKYRojVGV5tPEVbP/47yYIcAQrgjUFvUrQ7EY4O+acOyRlR4HXvIypsPPD0yQ7QYD21jtjzOfcOH3RUPJvOw873vEFu1lHqC6OfmOFlCoQQXJZlksM+g0pUhDTXUNPwx61dVIoj//gmirQegrMLKNWMKghSAUHIi2zu8Q== moritz@moritz-arch"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC/kpMY0vRcbp8Fx9vShGELFqUdC1RUGeupZ3y0GQvgsYKjYDG8jMD5Q/XCvGUa1jdj5NP47XzhFvrq0o5qcd+NfNdxVvPlYgaRb6PgpzrRZii/Vo4Fn/gWGIE8TPR/h1zb6uI7qvDiSvqsXNh0xbSnqVwMWc8xeUMP7brlPZfAlY2W3TbZ55v9z8s3Ef7+3r2lK2bEPtQv7WVlzpjViT3EcGt91i1TkiFhAWDbvBWycsri4TbuuILDZHOD5T8AVv74apUoHDIK3atoX57cAb1ZZeumPaENSzVE6QzSXXW49AY18pjjyup1JRnsJHPso9BB+AHkkborfClwBXCcKRyfNrEqOcq7QCGrRxptiHucTSiW72d8Boyu6XBfIN0o1bvVXnlw3fqBIr4VjEIbXTJDzTPF+U8J/6TRmX3JiwEFf2VodR+syA0ZxldNeWtCeaojBbVM9OfocLDh4errp9ys/m2Eou7aezRfGQiyS52zwfTF1Emexj4ppDEdNzW7l+E= moritz@htpc"
    ];
  };
}
