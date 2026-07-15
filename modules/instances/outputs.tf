output "instance_1_self_link" {
  description = "The self link of tf-instance-1"
  value       = google_compute_instance.tf-instance-1.self_link
}

output "instance_2_self_link" {
  description = "The self link of tf-instance-2"
  value       = google_compute_instance.tf-instance-2.self_link
}
