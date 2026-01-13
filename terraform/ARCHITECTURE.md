# BMI Health Tracker - Architecture Overview

## 📐 Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (Region)                       │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                        │ │
│  │                                                              │ │
│  │  ┌──────────────────────┐    ┌──────────────────────┐     │ │
│  │  │  Public Subnet       │    │  Public Subnet       │     │ │
│  │  │  10.0.1.0/24         │    │  10.0.2.0/24         │     │ │
│  │  │  AZ-1                │    │  AZ-2                │     │ │
│  │  │                      │    │                      │     │ │
│  │  │  ┌────────────────┐ │    │                      │     │ │
│  │  │  │  EC2 Instance  │ │    │   (Reserved for HA)  │     │ │
│  │  │  │  Ubuntu 22.04  │ │    │                      │     │ │
│  │  │  │  t3.medium      │ │    │                      │     │ │
│  │  │  │                 │ │    │                      │     │ │
│  │  │  │  ┌───────────┐ │ │    │                      │     │ │
│  │  │  │  │  Nginx    │ │ │    │                      │     │ │
│  │  │  │  │  Port 80  │◄├─┼────┼──────────────────────┼─────┼─┼── Internet
│  │  │  │  └─────┬─────┘ │ │    │                      │     │ │
│  │  │  │        │       │ │    │                      │     │ │
│  │  │  │  ┌─────▼─────┐ │ │    │                      │     │ │
│  │  │  │  │  Node.js  │ │ │    │                      │     │ │
│  │  │  │  │  Backend  │ │ │    │                      │     │ │
│  │  │  │  │  Port 3000│ │ │    │                      │     │ │
│  │  │  │  └─────┬─────┘ │ │    │                      │     │ │
│  │  │  │        │       │ │    │                      │     │ │
│  │  │  │  ┌─────▼─────┐ │ │    │                      │     │ │
│  │  │  │  │PostgreSQL │ │ │    │                      │     │ │
│  │  │  │  │   14      │ │ │    │                      │     │ │
│  │  │  │  │Port 5432  │ │ │    │                      │     │ │
│  │  │  │  └───────────┘ │ │    │                      │     │ │
│  │  │  └────────────────┘ │    │                      │     │ │
│  │  └──────────────────────┘    └──────────────────────┘     │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │              Internet Gateway                         │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Security Groups                              │ │
│  │  • SSH (22) - Restricted IP                              │ │
│  │  • HTTP (80) - 0.0.0.0/0                                 │ │
│  │  • PostgreSQL (5432) - localhost only                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              CloudWatch Logs                              │ │
│  │  • User data logs                                         │ │
│  │  • Backend application logs                               │ │
│  │  • Nginx access/error logs                                │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    S3 Backend (State Storage)                    │
│  • Terraform state file                                          │
│  • Versioning enabled                                            │
│  • Encryption enabled                                            │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Application Stack

### Frontend Layer
- **Technology**: React 18 + Vite
- **Server**: Nginx (reverse proxy + static file serving)
- **Port**: 80 (HTTP)
- **Features**:
  - BMI Calculator Form
  - Measurement History
  - Trend Charts (Chart.js)
  - Responsive UI

### Backend Layer
- **Technology**: Node.js + Express
- **Process Manager**: Systemd service
- **Port**: 3000 (localhost only, proxied by Nginx)
- **API Endpoints**:
  - POST /api/measurements (Create measurement)
  - GET /api/measurements (List measurements)
  - GET /api/measurements/:id (Get measurement)
  - DELETE /api/measurements/:id (Delete measurement)

### Database Layer
- **Technology**: PostgreSQL 14
- **Port**: 5432 (localhost only)
- **Database**: bmidb
- **Tables**:
  - measurements (id, weight_kg, height_cm, age, sex, activity_level, bmi, bmr, etc.)
- **Migrations**: Automated via SQL files

## 🔄 Data Flow

```
1. User Request
   ↓
2. Nginx (Port 80)
   ├─→ Static files (React app) → Served directly
   └─→ /api/* requests → Reverse proxy to Backend
                         ↓
3. Node.js Backend (Port 3000)
   ├─→ Business logic (BMI/BMR calculations)
   ├─→ Data validation
   └─→ Database queries
       ↓
4. PostgreSQL (Port 5432)
   ├─→ Store measurements
   └─→ Retrieve historical data
       ↓
5. Response (JSON)
   ↓
6. Frontend (React)
   └─→ Display results + charts
```

## 🔐 Security Model

### Network Security
- **VPC Isolation**: Custom VPC with controlled access
- **Security Groups**: Firewall rules at instance level
- **Public Access**: Only HTTP (80) and SSH (22)
- **Internal Only**: Backend (3000) and PostgreSQL (5432)

### Application Security
- **IMDSv2**: Required for instance metadata
- **CORS**: Configured for API access
- **Input Validation**: Backend validates all inputs
- **SQL Injection**: Protected via parameterized queries (pg library)
- **Environment Variables**: Sensitive data in .env files

### Access Control
- **SSH**: Key-based authentication only
- **IAM Role**: EC2 instance profile for AWS services
- **Database**: Password-protected PostgreSQL user

## 📊 Terraform Module Structure

```
terraform/
├── Root Configuration
│   ├── main.tf          # Module orchestration
│   ├── variables.tf     # Input variables
│   ├── outputs.tf       # Output values
│   ├── provider.tf      # AWS provider config
│   └── backend.tf       # S3 backend config
│
├── VPC Module
│   ├── Creates: VPC, Subnets, IGW, Route Tables
│   └── Outputs: VPC ID, Subnet IDs
│
├── Security Module
│   ├── Creates: Security Groups, Rules
│   └── Outputs: Security Group IDs
│
└── EC2 Module
    ├── Creates: EC2 Instance, IAM Role, CloudWatch Logs
    ├── User Data: Bootstrap script
    └── Outputs: Instance IP, DNS, IDs
```

## 🚀 Deployment Workflow

```
1. Terraform Init
   ├─→ Download providers
   ├─→ Configure S3 backend
   └─→ Initialize modules

2. Terraform Plan
   └─→ Preview resource changes

3. Terraform Apply
   ├─→ Create VPC & Networking
   ├─→ Create Security Groups
   ├─→ Create IAM Roles
   ├─→ Launch EC2 Instance
   └─→ Execute User Data Script
       ├─→ Update system
       ├─→ Install PostgreSQL
       ├─→ Install Node.js (NVM)
       ├─→ Install Nginx
       ├─→ Configure CloudWatch
       └─→ Wait for app code

4. Upload Application Code
   └─→ SCP/rsync files to EC2

5. Run Deployment Script
   ├─→ Setup database
   ├─→ Install dependencies
   ├─→ Run migrations
   ├─→ Build frontend
   ├─→ Configure Nginx
   └─→ Start services

6. Application Ready
   └─→ Access via HTTP
```

## 📈 Scalability Path

### Current: Single Instance
- All components on one EC2 instance
- Suitable for development/testing
- Cost-effective (~$40/month)

### Future: Multi-Tier
1. **Application Load Balancer** + Auto Scaling Group
2. **Amazon RDS PostgreSQL** (Multi-AZ)
3. **Amazon ElastiCache** (Redis for sessions)
4. **Amazon S3** + CloudFront (Static assets)
5. **Route 53** (DNS management)
6. **ACM** (SSL/TLS certificates)

### Future: High Availability
```
                    ┌─────────────┐
                    │  Route 53   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ CloudFront  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │     ALB     │
                    └──┬───────┬──┘
                       │       │
            ┌──────────▼─┐   ┌─▼──────────┐
            │ EC2 (AZ-1) │   │ EC2 (AZ-2) │
            └─────┬──────┘   └──────┬─────┘
                  │                 │
            ┌─────▼─────────────────▼─────┐
            │    RDS PostgreSQL (Multi-AZ) │
            └──────────────────────────────┘
```

## 🛠️ Technology Stack Summary

| Layer | Technology | Version |
|-------|-----------|---------|
| Infrastructure | Terraform | >= 1.0 |
| Cloud Provider | AWS | N/A |
| Operating System | Ubuntu | 22.04 LTS |
| Frontend Framework | React | 18.2.0 |
| Build Tool | Vite | 5.0.0 |
| Backend Runtime | Node.js | LTS (via NVM) |
| Backend Framework | Express | 4.18.2 |
| Database | PostgreSQL | 14 |
| Web Server | Nginx | Latest |
| Process Manager | Systemd | Native |
| Charts | Chart.js | 4.4.0 |

## 📝 Key Features

### BMI Calculation
- Weight (kg), Height (cm), Age, Sex inputs
- BMI formula: weight / (height/100)²
- Categories: Underweight, Normal, Overweight, Obese

### BMR Calculation
- Mifflin-St Jeor Equation
- Male: (10 × weight) + (6.25 × height) - (5 × age) + 5
- Female: (10 × weight) + (6.25 × height) - (5 × age) - 161

### Daily Calorie Needs
- BMR × Activity Factor
- Sedentary (×1.2) to Very Active (×1.9)

### Data Persistence
- All measurements stored in PostgreSQL
- Historical tracking with timestamps
- Trend visualization with charts

---

**Architecture Version**: 1.0  
**Last Updated**: January 2026  
**Status**: Production Ready for Single Instance Deployment
