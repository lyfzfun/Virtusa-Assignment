With custom VPCs, you can:

Distribute resources across multiple Availability Zones (AZs)

Create multiple subnets per AZ (for zone-aware services)

Use custom route tables for advanced networking


1. HTTPS Support:
   - Add TLS certificates using AWS ACM and ALB HTTPS listener.

2. CI/CD Pipeline:
   - Use CodePipeline/CodeDeploy to automatically update content on S3 and EC2.

4. Content Caching:
   - Use CloudFront or tools like Redis to cache and deliver content globally with low latency.

5. Health Checks:
   - Add detailed Nginx or app-specific health checks in target groups for better failover.

6. Monitoring:
   - Integrate with CloudWatch for better insights and alerting.


Code Improvements:

- Can cleanup the main file and create separate modules for S3, Launch template, Security, etc and then call them in the main.tf file.
- User data script can be passed through <user_data.sh> file

