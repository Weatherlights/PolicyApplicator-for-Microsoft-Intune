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
Here you can configure namespaces for the xpath. Each namespace can be specified by adding the prefix and the url of the namespace seperated by &amp;#xF000;.

Example: prefix1&amp;#xF000;namespaceuri1&amp;#xF000;prefix2&amp;#xF000;namespaceuri2

#### xpath
Here you can specify the xpath that resolved the setting in your configuration file. You should not use complex xpath expressions.

Good: /element1/element2/@attribute

Bad: //@attribute

#### value
Enter your desired configuration value here.

### ini configurations
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

#### section
This information is used to determine in which section your configuration resides.

#### key
This information is used to determine the specific key in the given section that you want to check and configure.

#### value
The value the you want the configuration element to be.

### list configurations

#### operation
This allows you to configure how the PolicyApplicator will treat an element within the file in case of a configuration missmatch:
* replace <em>Default</em>
   * In case the configuration element does not exist it gets created from the policy.
   * In case the configuration element does not match the policy it is reconfigured from the policy.

#### list
Here you can specify the list entries you want your file to have. Each entry must have a unique number and the entry value seperated by &amp;#xF000;.

Example: 0&amp;#xF000;EntryA&amp;#xF000;1&amp;#xF000;EntryB&amp;#xF000;2&amp;#xF000;EntryC