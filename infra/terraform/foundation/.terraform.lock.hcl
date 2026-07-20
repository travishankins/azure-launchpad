# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/azure/azapi" {
  version     = "2.10.0"
  constraints = "~> 2.0, ~> 2.2, ~> 2.4, ~> 2.5"
  hashes = [
    "h1:R6NYsRfXHXd5eNBFAG5gIyD8Um2nFgXiqB5Uz6vHAsA=",
    "zh:1e6513c791c6be1389fc4acb8ffdd5127dbf0f479bd0c0074d3a5b69edee2faa",
    "zh:2ad99c9b656a1d796f4f0ae50d98064af0e42915bbb5a9e5a8db68ca633eceb3",
    "zh:455fcbfe38cf9181fbd78a6a4a1e43ccafbb606757f4142c99a8ce4d0c80b34c",
    "zh:46dcafe5495aa50984fd393e72d18d59370fd6bb36b44a0c6c034b82644fc7b7",
    "zh:5b2f0acff55ee9f8896e11b14d0538fc929d7eee0d68a15644751ca8b6cbc2fc",
    "zh:61e231f5c6d300404e1010aff9634638c533ba2a7279b85df43cff3aec60f1a9",
    "zh:68d0aefbd2baf276a034037d6e8b7b9049af42e5745a6db1cbc3311b79de0e6d",
    "zh:8b12924ee9125266d6aee30a818c1d90403eefad82753b5cd70c8c20ddbd3c98",
    "zh:92f5643c18c67d3c4bd1b03c02bc7069b24936b2cb5fca58fb998452dfa46e04",
    "zh:a7aa502ba10433dbe6695a0b903d642153a99540e4eba2befe97e3902fd98093",
    "zh:c3f8155d5b609fa336eb79c7b67b75076d9c31c94e53d2f3d2b2e66b58e1a73f",
    "zh:e670ae37ed1813e8e475962a109652a15a054111b2b2428435deab884937ff1e",
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
  version     = "4.81.0"
  constraints = ">= 3.7.0, >= 3.71.0, >= 3.117.0, ~> 4.16, >= 4.36.0, < 5.0.0"
  hashes = [
    "h1:XhToZua4gtih1Kv8RdStcfND83G4Tmb6GZFT4jEUhDU=",
    "zh:0732e7b74264ddfa2b90ba69d01c283d3cbae9f72ed3e506c6ac92529fed7fd3",
    "zh:12afb524e232fe4e3d6161927724af5dfa4831d71edd9c174917ca9b7377bfae",
    "zh:169d619ae202c4145e02fb706fb7c3679445ab3e3ff722edbf89597517a8c92e",
    "zh:6beb95a3ef2f2d9c76abaa48e5450e90686a3fb6a47f1cb0ff7c5e94b6960151",
    "zh:705e075fb5ffc4bf66fd7cbabf1a65007a41621e80030a2c158a4c83b6046216",
    "zh:78d5eefdd9e494defcb3c68d282b8f96630502cac21d1ea161f53cfe9bb483b3",
    "zh:79a8d17fefe647040fcb9ee8821a4f09f395427c4fd49493489b9a93a9a1038e",
    "zh:8cc3f900b3774c0ae37ae42365c4579a199cf9e5edf88e476fdf5ab1048f84ea",
    "zh:dec373b9390fa95e257291acd018ed65a7d512b428645d35e22cdbe8b245a08b",
    "zh:e60f1e9fb45df6defade2855ed6e68547409ea75d30655c556adb0c08579749b",
    "zh:f901d12ec82f3f8b5880a27b5cbcd7bd0d97e60c9367a2d7ed82fdd1157b39ff",
    "zh:facf68ea5bf0f2b8ba720e7fba5f86492e1d4c591100460bb91c3f79f391f4b6",
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
