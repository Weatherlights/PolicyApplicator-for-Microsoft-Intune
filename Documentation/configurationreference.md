# Configuration Reference
### File configurations
File configurations apply to an entire file. They tell the PolicyApplicator Agent how to create or remediate a file that is not in compliance with your configuration.
#### File-operation
This allows you to configure how the PolicyApplicator modifies an entire file in case of a configuration missmatch:
* create <em>Default</em>
   * Creates a file if it does not exist yet and writes the configuration from the policy.
   * In case the file already exists only the missconfigured configuration is modified.
* update
   * In case the file does not exist the PolicyApplicator does nothing.
   * In case the file already exists only the missconfigured configuration is modified.
* replace
   * Creates a file if it does not exist yet and writes the configuration from the policy.
   * In case the file already exists and is missconfigured the entire file will be recreated from the policy.

#### File-encoding
Here you can specify the encoding of the file that may get recreated by the PolicyApplicator. Possible values are:
* utf8
* utf7
* unicode
* bigendianunicode
* utf32
* ascii
* Default
* OEM

### XML configurations
#### operation
This allows you to configure how the PolicyApplicator will treat an element within the file in case of a configuration missmatch:
* create
   * In case the configuration element does not exist it gets created from the policy.
   * In case the configuration element does not match the policy it is ignored.
* delete
   * In case the configuration element does not exist it is ignored.
   * In case the configuration element does exist it is deleted.
* update
   * In case the configuration element does not exist it is ignored.
   * In case the configuration element does not match the policy it is reconfigured from the policy.
* replace <em>Default</em>
   * In case the configuration element does not exist it gets created from the policy.
   * In case the configuration element does not match the policy it is reconfigured from the policy.

#### namespace
Here you can configure namespaces for the xpath. Each namespace can be configured like this:
