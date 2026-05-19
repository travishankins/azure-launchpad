# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/azure/azapi" {
  version     = "2.9.0"
  constraints = "~> 2.0, ~> 2.2, ~> 2.4, ~> 2.5"
  hashes = [
    "h1:ivmN39jnMJRZXlPuX8r5TTXM8lyF8ZocPQQgEUy61eM=",
    "zh:0a4eee8c9362db6ca19d371eccf38701c8306be761182da87b624294f7e8f867",
    "zh:4df87bee5b8f4cce27461ae26132a599542583cdf035942b42b0259a514ab46e",
    "zh:57dc1f4227f1d0eab630fcf868d6c9a1b4dc4c165608ce5a4d7028a482770547",
    "zh:5c500e42c419c324ea8f41c40e4cc8af187323cebc9f70543749b6c0e59c0fe9",
    "zh:6c7dca31242e27d2f215b1a9370b65579b3a988282a3609564ea96866f86f0ca",
    "zh:74dada7351b25d01e61aa70aa8cf1f1fb96d09c514be4b66d12816c5e61f9e01",
    "zh:9c67c0727ab8be15879793f929f3d71f0f149ae1daaf577d0bd4d57b2e61c408",
    "zh:a0266da16db14b635a61d6766efc28468056bac91ed6662fc9f2a0aad923b063",
    "zh:a4a555627f40fa797b34ddede599812cddb1e0e9be105ccfcf1f293451b97cd7",
    "zh:a6a1c4a46f4f01e4420a456adefe8bcf3bff3c9d09a8dfeedeea5b94c866dfd8",
    "zh:c64fc4067a8276d4405d9359990e0c45e66dba07433a1f3ab1e6c32f6ef3b048",
    "zh:ee77a881d071b3a0ad8a64f9c1158e3aee9b37e9063de5dd8fa9d238dbe70ba1",
  ]
}

provider "registry.terraform.io/azure/modtm" {
  version     = "0.3.5"
  constraints = "~> 0.3"
  hashes = [
    "h1:RmCHYU3U3jDGYruN3Q7PiQqwqg7U4WP3dUDbx1PsyQ4=",
    "zh:02a54109f2bd30a089a0681eaba8ef9d30b0402a51795597ee7b067f04952417",
    "zh:0a15492a7257a0979d1f1d501168d1a38ec8c65b11d89d9423349f143d7b7e67",
    "zh:4ae1d114aec1625f192eb2055eb7301774a8f79340085fbbe7c2d11284ba4cb7",
    "zh:599201c19e82a227f0739be2150779e42903ba0aa147e96ef219c7f32f926053",
    "zh:747b1189e679cd7cf77f76fd09609db0ac1ef7189ec3c64accd37af7d0ebe449",
    "zh:859bc8739ceb9049e7cd98284f22eb9d503cc5b80f9452ee28a518080ebf3903",
    "zh:8f97c0876b30967b47dfd63546f3843368bc3bc90e98bb42bd33c00ffe2d0b2c",
    "zh:91183bbea386e6013d0b2a3b1d36a7bfe1595d45f4ee1f4f693d6254d017d334",
    "zh:ae16303a74c83e0d8f4413d568eaf04c3c0d2b07250dbd7ae07bffae01197f36",
    "zh:db155386bb65a7fd5569b7d3331de65a259638e8e1c8f8896db969f4599504a9",
    "zh:e39e6089c8a17a4b26b59c95050bd0e19fc0a09a14314cfa139053269b6d5f8d",
    "zh:ec880b514fc3bd8d07e5d66a0c528fd6d83ae62d6588df4939b1f6ea509f0b24",
  ]
}

provider "registry.terraform.io/hashicorp/azurerm" {
  version     = "4.71.0"
  constraints = ">= 3.7.0, >= 3.71.0, >= 3.117.0, ~> 4.0, ~> 4.16, >= 4.36.0, < 5.0.0"
  hashes = [
    "h1:3Y3Ekb3dj0RmY5cvGDO9PBAQ79aT3vm7Ykf8t6h3gqs=",
    "zh:01cc81ba9951d84757321918fdca7fe69ceed3570c57b8243c446fd8e2566ec4",
    "zh:0cf2e5e039b772f3eeaaeadc53828b07c0bb861562915bfcbc5c884871075c1c",
    "zh:22c53af5beddc85c66b28f1892ac043bcce8efb578d89c03256e69aed98629b5",
    "zh:2e1c3b917ae247b2d23a48e38870f27f12a4e196d50f19f2b3fe0e78223e499b",
    "zh:380e908e885673605c26c1ea2181a94eac99600b2c3126f3ae8b99323ddd9cd6",
    "zh:386e15eb9c9538486334a543b662701905151dc34db73c5e1849d3814f5484ac",
    "zh:5e4a8bf18c649940b59c5cf6cd6e53cf901014aad9bc995987a4c4cb1352f100",
    "zh:78d5eefdd9e494defcb3c68d282b8f96630502cac21d1ea161f53cfe9bb483b3",
    "zh:7c1d971aa318240ce6f81131803a495da8a095a1ab260a3f670090487b542834",
    "zh:8ed8d8d1074cc6fcc2f39efd84de8eaaf565d15fdbf52ed16ac9adb2d397a4b6",
    "zh:9cd754daa817c60688695e58da3a118686ff79a7c7f29446d3f74056319fe0fb",
    "zh:fd6f9b6b3276809c0674c46e25e97df281f136d4c25d3d7820cacd2f04a1c664",
  ]
}

provider "registry.terraform.io/hashicorp/random" {
  version     = "3.9.0"
  constraints = ">= 3.5.0, ~> 3.5, >= 3.5.1, ~> 3.6, < 4.0.0, < 5.0.0"
  hashes = [
    "h1:OO+IuvQJSPmWdN8AyyIEvPJbLvDQpgX/zbktoa9KsJE=",
    "zh:161ad0bd9a75768c82f53fb6e7172a9d8be2d4889b012645a34795031aaf1bf1",
    "zh:19dc9a5b17729725ccfc4f45b0500af0ee5bc6b6b160c7adb8f2bf617d2c80ea",
    "zh:269eda8fe42daa7974d5a34d166c3ba9defe80cde86c01e4dadcfdf2e1f05e5f",
    "zh:373f7c65566f8f2cc7f45d698654feb9d988996957e1266a69ca00c52d6d16d0",
    "zh:5599d16804c41c83009ec621b6d6b6f74e102f5827678a4750f8809055546b61",
    "zh:583be0440469a22bff70dcfa56593b01566860b29607437264adb51060cf46fc",
    "zh:5f211d8ec3f2e1f414870d9584bfe26e6995560ef81c748f8447a48164767398",
    "zh:78d5eefdd9e494defcb3c68d282b8f96630502cac21d1ea161f53cfe9bb483b3",
    "zh:7b547fd16216761ef86efc3ed516ac5ac0c5c42b7c7eb24a08cef2d93f69ed5e",
    "zh:7e7c0679daf2a382151d05068c8c3f0dae6b7b7dccf818827b73dd08638df2ef",
    "zh:8089dec888a8038b9b4fb23b3df7e1057293dbc5b60b42cc47ff690d69d4b61b",
    "zh:c51f15a031edfd6f23ce8ced3446ca7f8d8d647e2499890d7d5d10d5016d7257",
    "zh:c94784f005708890dc6895afd53636ec00ec1e430b15d41e5aebfb1d4b39bd04",
  ]
}

provider "registry.terraform.io/hashicorp/time" {
  version     = "0.13.1"
  constraints = "~> 0.9, ~> 0.13, ~> 0.13.1"
  hashes = [
    "h1:ZT5ppCNIModqk3iOkVt5my8b8yBHmDpl663JtXAIRqM=",
    "zh:02cb9aab1002f0f2a94a4f85acec8893297dc75915f7404c165983f720a54b74",
    "zh:04429b2b31a492d19e5ecf999b116d396dac0b24bba0d0fb19ecaefe193fdb8f",
    "zh:26f8e51bb7c275c404ba6028c1b530312066009194db721a8427a7bc5cdbc83a",
    "zh:772ff8dbdbef968651ab3ae76d04afd355c32f8a868d03244db3f8496e462690",
    "zh:78d5eefdd9e494defcb3c68d282b8f96630502cac21d1ea161f53cfe9bb483b3",
    "zh:898db5d2b6bd6ca5457dccb52eedbc7c5b1a71e4a4658381bcbb38cedbbda328",
    "zh:8de913bf09a3fa7bedc29fec18c47c571d0c7a3d0644322c46f3aa648cf30cd8",
    "zh:9402102c86a87bdfe7e501ffbb9c685c32bbcefcfcf897fd7d53df414c36877b",
    "zh:b18b9bb1726bb8cfbefc0a29cf3657c82578001f514bcf4c079839b6776c47f0",
    "zh:b9d31fdc4faecb909d7c5ce41d2479dd0536862a963df434be4b16e8e4edc94d",
    "zh:c951e9f39cca3446c060bd63933ebb89cedde9523904813973fbc3d11863ba75",
    "zh:e5b773c0d07e962291be0e9b413c7a22c044b8c7b58c76e8aa91d1659990dfb5",
  ]
}
