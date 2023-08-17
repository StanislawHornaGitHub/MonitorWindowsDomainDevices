/* groovylint-disable CompileStatic */
pipeline {
    agent any
    stages {
        stage('Test-ActiveDevices') {
            steps {
                build 'Test-ActiveDevices'
            }
        }
        stage('Collect Event Data') {
            steps {
                parallel CPUandRAM: {
                    build 'Get-CPUandRAMusage'
                }
            }
        }
    }
}
