{ config, pkgs, ... }:
{
  users.users.moritz = {
    isNormalUser = true;
    home = "/home/moritz";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAuTjHw/LFq2JW9YlpZJSreTXUqTOoDhBRLni2G0jqsd7vTbSpbUektk9o4OnV1PUYuKXCa9Z/PYjf/VQF8uthb1zF9FSKDL8mlB/u8QYy+6n2aNQh+/ZFQ10Hq0sI3DiggYiNjb77AU04W19N7KgZlTAOjMVL5+gsEV13u4PNs/otqg4ID3yhHj5WiKUkiv910SAfHiwnJcwI0MUQYIz80eUM5vsMitaB57fFUE/jVIgfy0i7mt6Fvbx5lqhRrSXaW48cd87CvU8HNO6D5dwlvqTKs1nKTWbRNqDnSR9mGtnaKVWnaeMByMdvovpdn3na8Yw2uIrK187hLxeNTHZDB6TqjprZVearRG1Aw8/HTYeJwb7B0XvKn9LCSCWFtuFP52TVK8+YfLAwXOs5Q+D6x1qzwRXmRV697P5tADrD/UGnBAKk7xGwy3ocqcSq6ap+aloGhQ54lnRSyPBGtgSzRbSodHx9TTMhgHfvIMasEI+7+Kxzuhc0LBDJCTK/bFN4ySgfzIKYRojVGV5tPEVbP/47yYIcAQrgjUFvUrQ7EY4O+acOyRlR4HXvIypsPPD0yQ7QYD21jtjzOfcOH3RUPJvOw873vEFu1lHqC6OfmOFlCoQQXJZlksM+g0pUhDTXUNPwx61dVIoj//gmirQegrMLKNWMKghSAUHIi2zu8Q== moritz@moritz-arch"
    ];
  };
}
