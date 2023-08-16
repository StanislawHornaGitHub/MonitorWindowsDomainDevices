/* groovylint-disable CompileStatic */
pipeline {
    agent any
    stages {
        stage('Test-ActiveDevices') {
            steps {
                build 'Test-ActiveDevices'
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
                }, Boot : {
                    build 'Get-BootInformation'
                }
            }
        }
    }
}
