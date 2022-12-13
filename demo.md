### Add Scrape config


    - job_name: airflow-poc
      honor_timestamps: true
      scrape_interval: 30s
      scrape_timeout: 10s
      metrics_path: /admin/metrics
      scheme: http
      static_configs:
      - targets:
        - airflow-poc.aws.aurotfp.com:8080

k apply -f ../configs/prometheus-extra.yaml

### Add Extra Dashboard


k apply -f ../configs/blackbox-dashboard.yaml
k apply -f ../configs/jenkins-dashboard.yaml


### Add Alert

k apply -f ../configs/crypto-alert.yaml