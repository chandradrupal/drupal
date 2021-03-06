#!/usr/bin/env php
<?php
// $Id: generate-d6-content.sh,v 1.1 2010-07-30 01:28:00 dries Exp $

/**
 * Generate content for a Drupal 6 database to test the upgrade process.
 *
 * Run this script at the root of an existing Drupal 6 installation.
 * Steps to use this generation script:
 * - Install drupal 6.
 * - Run this script from your Drupal ROOT directory.
 * - Use the dump-database-d6.sh to generate the D7 file
 *   modules/simpletest/tests/upgrade/database.filled.php
 */

// Define settings.
$cmd = 'index.php';
$_SERVER['HTTP_HOST']       = 'default';
$_SERVER['PHP_SELF']        = '/index.php';
$_SERVER['REMOTE_ADDR']     = '127.0.0.1';
$_SERVER['SERVER_SOFTWARE'] = NULL;
$_SERVER['REQUEST_METHOD']  = 'GET';
$_SERVER['QUERY_STRING']    = '';
$_SERVER['PHP_SELF']        = $_SERVER['REQUEST_URI'] = '/';
$_SERVER['HTTP_USER_AGENT'] = 'console';
$modules_to_enable          = array('path', 'poll');

// Bootstrap Drupal.
include_once './includes/bootstrap.inc';
drupal_bootstrap(DRUPAL_BOOTSTRAP_FULL);

// Enable requested modules
include_once './modules/system/system.admin.inc';
$form = system_modules();
foreach ($modules_to_enable as $module) {
  $form_state['values']['status'][$module] = TRUE;
}
$form_state['values']['disabled_modules'] = $form['disabled_modules'];
system_modules_submit(NULL, $form_state);
unset($form_state);

// Run cron after installing
drupal_cron_run();

// Create six users
for ($i = 0; $i < 6; $i++) {
  $name = "test user $i";
  $pass = md5("test PassW0rd $i !(.)");
  $mail = "test$i@example.com";
  $now = mktime(0, 0, 0, 1, $i + 1, 2010);
  db_query("INSERT INTO {users} (name, pass, mail, status, created, access) VALUES ('%s', '%s', '%s', %d, %d, %d)", $name, $pass, $mail, 1, $now, $now);
}


// Create vocabularies and terms

$terms = array();

// All possible combinations of these vocabulary properties.
$hierarchy = array(0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2);
$multiple  = array(0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1);
$required  = array(0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1);

for ($i = 0; $i < 24; $i++) {
  $vocabulary = array();
  $vocabulary['name'] = "vocabulary $i";
  $vocabulary['description'] = "description of ". $vocabulary['name'];
  $vocabulary['nodes'] = $i > 11 ? array('page' => TRUE) : array();
  $vocabulary['multiple'] = $multiple[$i % 12];
  $vocabulary['required'] = $required[$i % 12];
  $vocabulary['relations'] = 1;
  $vocabulary['hierarchy'] = $hierarchy[$i % 12];
  $vocabulary['weight'] = $i;
  taxonomy_save_vocabulary($vocabulary);
  $parents = array();
  // Vocabularies without hierarcy get one term, single parent vocabularies get
  // one parent and one child term. Multiple parent vocabularies get three
  // terms: t0, t1, t2 where t0 is a parent of both t1 and t2.
  for ($j = 0; $j < $vocabulary['hierarchy'] + 1; $j++) {
    $term = array();
    $term['vid'] = $vocabulary['vid'];
    // For multiple parent vocabularies, omit the t0-t1 relation, otherwise
    // every parent in the vocabulary is a parent.
    $term['parent'] = $vocabulary['hierarchy'] == 2 && i == 1 ? array() : $parents;
    $term['name'] = "term $j of vocabulary $i";
    $term['description'] = 'description of ' . $term['name'];
    $term['weight'] = $i * 3 + $j;
    taxonomy_save_term($term);
    $terms[] = $term['tid'];
    $parents[] = $term['tid'];
  }
}

module_load_include('inc', 'node', 'node.pages');
for ($i = 0; $i < 24; $i++) {
  $uid = intval($i / 8) + 3;
  $user = user_load($uid);
  $node = new stdClass;
  $node->uid = $uid;
  $node->type = $i < 12 ? 'page' : 'story';
  $node->sticky = 0;
  $node->title = "node title $i";
  $type = node_get_types('type', $node->type);
  if ($type->has_body) {
    $node->body = str_repeat("node body ($node->type) - $i", 100);
    $node->teaser = node_teaser($node->body);
    $node->filter = variable_get('filter_default_format', 1);
    $node->format = FILTER_FORMAT_DEFAULT;
  }
  $node->status = intval($i / 4) % 2;
  $node->language = '';
  $node->revision = $i < 12;
  $node->promote = $i % 2;
  $node->created = $now + $i * 86400;
  $node->log = "added $i node";
  $node->taxonomy = $terms;
  // Just make every term association different a little.
  unset($node->taxonomy[$i], $node->taxonomy[47 - $i]);
  node_save($node);
  path_set_alias("node/$node->nid", "content/$node->created");
  if ($node->revision) {
    $user = user_load($uid + 3);
    $node->title .= ' revision';
    $node->body = str_repeat("node revision body ($node->type) - $i", 100);
    $node->log = "added $i revision";
    node_save($node);
  }
}

// Create poll content
for ($i = 0; $i < 12; $i++) {
  $uid = intval($i / 4) + 3;
  $user = user_load($uid);
  $node = new stdClass;
  $node->uid = $uid;
  $node->type = 'poll';
  $node->sticky = 0;
  $node->title = "poll title $i";
  $type = node_get_types('type', $node->type);
  if ($type->has_body) {
    $node->body = str_repeat("node body ($node->type) - $i", 100);
    $node->teaser = node_teaser($node->body);
    $node->filter = variable_get('filter_default_format', 1);
    $node->format = FILTER_FORMAT_DEFAULT;
  }
  $node->status = intval($i / 2) % 2;
  $node->language = '';
  $node->revision = 1;
  $node->promote = $i % 2;
  $node->created = $now + $i * 43200;
  $node->log = "added $i poll";

  $nbchoices = ($i % 4) + 2;
  for ($c = 0; $c < $nbchoices; $c++) {
    $node->choice[] = array('chtext' => "Choice $c for poll $i");
  }
  node_save($node);
  path_set_alias("node/$node->nid", "content/poll/$i");
  path_set_alias("node/$node->nid/results", "content/poll/$i/results");

  // Add some votes
  for ($v = 0; $v < ($i % 4) + 5; $v++) {
    $c = $v % $nbchoices;
    $form_state = array();
    $form_state['values']['choice'] = $c;
    $form_state['values']['op'] = t('Vote');
    drupal_execute('poll_view_voting', $form_state, $node);
  }
}
