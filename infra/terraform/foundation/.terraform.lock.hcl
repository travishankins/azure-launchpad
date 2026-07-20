# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/azure/azapi" {
  version     = "2.11.0"
  constraints = "~> 2.0, ~> 2.2, ~> 2.4, ~> 2.5"
  hashes = [
    "h1:ugg8/PgFN9EGskrKfWpaqEmiiyjEG7y6AgUhe8fnAVI=",
    "zh:05ae9abf23abf003229e9e04734fce2b881974b0df4313083a890d9f67b1fc35",
    "zh:1dc85011f0dc8480d34d4fab9fe90de56e171d99b8b19d7b65b0f3ed2af20376",
    "zh:21f84feed46eba054575e5866dfef2e1073b7fc129d789ff16a1fc53802bdcd9",
    "zh:27f2f26c1e42a648d250d5911722f7aeeb5f15ed2982bea5c55075c39b8e0848",
    "zh:2e1a2cbef57ae39a4e8f70d900ae07cf9b751f70cbcc92172cf627e984d2d32c",
    "zh:53130ebb58fd9a9a8e916e234253ee38916303f69c26100574f4f0d66d19327e",
    "zh:6dca6143c9eb3184574eaf67a6294bf4378416efa4de1dd3734af53043e499f2",
    "zh:8377df97253638c6fea0b2f6e02835f06bd58e8c6864371050111d37e2352182",
    "zh:87f891986bac05ddc5c75938eeae5bc53b45adef22dd9d8b202e5fa4f978cda3",
    "zh:8cf0b1b1e064ea0bc4c785e68f2b239a57ffece529b21a60b415b9d310a610a9",
    "zh:97e827f791c2f33c23f37a98d150a5d8c244cfa8967d5c6f742dc5757b1377d3",
    "zh:9cb08cdb6e54bc380bd22add9522767c45457b322a26cdad7d7bb33d07ba3aa7",
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
  version     = "4.78.0"
  constraints = ">= 3.7.0, >= 3.71.0, >= 3.117.0, ~> 4.0, ~> 4.16, >= 4.36.0, < 5.0.0"
  hashes = [
    "h1:6MQ2q38HDc+UElLT8Sak5OqvxagxijWyElv259wTryQ=",
    "zh:0d304aa909cc991ebde65d69c46f9843b08e88c3e9e0da14135ffa0da6aa2d16",
    "zh:30e3e8ca8e21d58db6e6136bb04e62cfb2e1c6806598fb472e8d7a1a73911eec",
    "zh:37b313bb082883568e16afe8f389bcf30e5eba0367b0dce52f5206d17237c8d8",
    "zh:3fb84cfb9cce89e5abc5b066708a2aa84913bc5fa2c97d2aa89082a84de5fc51",
    "zh:78d5eefdd9e494defcb3c68d282b8f96630502cac21d1ea161f53cfe9bb483b3",
    "zh:b622594b5024b3f7d37705e0fa2ceb7cd9fd6957e2d6f53b17b5dd7f6297cf4e",
    "zh:c49ac67474cae86f6792db6042739a2a08a8ec38c5fcfd5d9764b5835595614a",
    "zh:ce4031214a3f7ba267f1ae2d24b1e4e9e394af2afc4ea7833e67116a5042a614",
    "zh:d0de2877cf64c91a7734cd170a4e1ec91e8822655760317b1a5e03c61cca3241",
    "zh:e573830323bd1df38a0589e3f23c3f4124e1d8ab7875eeeec63e97fecdf48f4c",
    "zh:f0c975ba9d6b7420f38e45e38adfe22f1b88ebed003bae35cb2c9223f36c79f5",
    "zh:f75cc41e621ac23cbc948570672b191d69f9d4056342a8e82f1c59cb9f76b2df",
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
