/* groovylint-disable CompileStatic */
pipeline {
    agent any
    stages {
        stage('Get-DeviceInventoryToMonitor') {
            steps {
                build 'Get-DeviceInventoryToMonitor'
            }
        }
        stage('Collect Object Data') {
            steps {
                parallel OS: {
                    build 'Get-OSVersionInformation'
                }, Hardware: {
                    build 'Get-DeviceHardwaredetails'
                }, Volume: {
                    build 'Get-VolumeSpace'
                }
            }
        }
    }
}
