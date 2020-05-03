# Mirror base image from Dockerhub image into Google Container Registry
module "docker-mirror" {
  source      = "github.com/neomantra/terraform-docker-mirror"
  image_name  = local.base_image_name
  image_tag   = local.base_image_tag
  dest_prefix = "eu.gcr.io/${local.project}"
}

# Hydrate docker template file into .build directory
resource "local_file" "dockerfile" {
  content = templatefile("${path.module}/Dockerfile.template", {
    project = local.project
    image   = local.base_image_name
    tag     = local.base_image_tag
  })
  filename = "${path.module}/.build/Dockerfile"
}

# Hydrate config into .build directory
resource "local_file" "config" {
  content = templatefile("${path.module}/default.template.conf", {
  })
  filename = "${path.module}/.build/default.conf"
}

# Build a customized image
resource "null_resource" "openresty_image" {
  triggers = {
    # Rebuild if we change the base image, dockerfile, or bpm-platform config
    image = "eu.gcr.io/${local.project}/openresty:${local.base_image_tag}_${
      sha1(
        "${sha1(local_file.dockerfile.content)}${sha1(local_file.config.content)}"
      )  
    }"
  }
  provisioner "local-exec" {
    command = <<-EOT
        gcloud builds submit \
        --project ${local.project} \
        --tag ${self.triggers.image} \
        ${path.module}/.build
    EOT
  }
}
