terraform {

 backend "s3" {
   key                         = "tfstate"
   bucket                      = "poc-gardener"
   region                      = "s3-minio"
   skip_credentials_validation = true
   skip_metadata_api_check     = true
   skip_region_validation      = true
   force_path_style            = true
 }

}
