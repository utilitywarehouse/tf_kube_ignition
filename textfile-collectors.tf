data "ignition_systemd_unit" "node_textfile_inode_fd_count_service" {
  name    = "node_textfile_inode_fd_count.service"
  enabled = false # not enabled because this service is started by a timer
  content = file("${path.module}/resources/node_textfile_inode_fd_count.service")
}

data "ignition_systemd_unit" "node_textfile_inode_fd_count_timer" {
  name    = "node_textfile_inode_fd_count.timer"
  content = file("${path.module}/resources/node_textfile_inode_fd_count.timer")
}

data "ignition_file" "node_textfile_inode_fd_count" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/node_textfile_inode_fd_count"

  content {
    content = file("${path.module}/resources/node_textfile_inode_fd_count")
  }
}
