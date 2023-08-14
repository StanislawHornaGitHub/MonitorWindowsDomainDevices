/* groovylint-disable CompileStatic */
pipeline {
    agent any
    stages {
        stage('Test-ActiveDevices') {
            steps {
                build 'Get-DeviceInventoryToMonitor'
            }
        }
    }
}
